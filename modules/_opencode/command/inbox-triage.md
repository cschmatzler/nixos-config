---
description: Triage inbox one message at a time with himalaya only
---

Process email with strict manual triage using Himalaya only.

Hard requirements:
- Use `himalaya` for every mailbox interaction (folders, listing, reading, moving, deleting, attachments).
- Process exactly one message ID at a time. Never run bulk actions on multiple IDs.
- Do not use pattern-matching commands or searches (`grep`, `rg`, `awk`, `sed`, `himalaya envelope list` query filters, etc.).
- Always inspect current folders first, then triage.
- Treat this as a single deterministic run over a snapshot of message IDs discovered during this run.
- Ingest valuable document attachments into Paperless (see Document Ingestion section below).

Workflow:
1. Run `himalaya folder list` first and use those folders as the primary taxonomy.
2. Use this existing folder set as defaults when it fits:
   - `INBOX`
    - `Correspondence`
    - `Orders and Invoices`
    - `Payments`
    - `Outgoing Shipments`
    - `Newsletters and Marketing`
    - `Junk`
    - `Deleted Messages`
3. Determine source folder:
   - If `$ARGUMENTS` is a single known folder name (matches a folder from step 1), use that as source.
   - Otherwise use `INBOX`.
4. Build a run scope safely:
   - List with fixed page size `20` and JSON output: `himalaya envelope list -f "<source>" -p 1 -s 20 --output json`.
   - Start at page `1`. Enumerate IDs in returned order.
   - Process each ID fully before touching the next ID.
   - Keep an in-memory reviewed set for this run to avoid reprocessing IDs already handled or intentionally left untouched.
   - When all IDs on the current page are in the reviewed set, advance to the next page.
   - Stop when a page returns fewer results than the page size (end of folder) and all its IDs are in the reviewed set.
5. For each single envelope ID, do all checks before any move/delete:
    - Check envelope flags from the JSON listing (seen/answered/flagged) before reading.
    - Read the message: `himalaya message read -f "<source>" <id>`.
    - If needed for classification or ingestion, download attachments: `himalaya attachment download -f "<source>" <id> --dir /tmp/himalaya-triage`.
    - If the message qualifies for document ingestion (see Document Ingestion below), copy eligible attachments to the Paperless consume directory before cleanup.
    - Always `rm` downloaded files from `/tmp/himalaya-triage` after processing (whether ingested or not).
    - Move: `himalaya message move -f "<source>" "<destination>" <id>`.
    - Delete: `himalaya message delete -f "<source>" <id>`.
6. Classification precedence (higher rule wins on conflict):
    - **Actionable and unhandled** — if the message needs a reply, requires manual payment, needs a confirmation, or demands any human action, AND has NOT been replied to (no `answered` flag), leave it in the source folder untouched. This is the highest-priority rule: anything that still needs attention stays in `INBOX`.
    - Human correspondence already handled — freeform natural-language messages written by a human that have been replied to (`answered` flag set): move to `Correspondence`.
    - Human communication not yet replied to but not clearly actionable — when in doubt whether a human message requires action, leave it untouched.
    - Clearly ephemeral automated/system message (alerts, bot/status updates, OTP/2FA, password reset codes, login codes) with no archival value: move to `Deleted Messages`.
    - Automatic payment transaction notifications (charge/payment confirmations, receipts, failed-payment notices, provider payment events such as Klarna/PayPal/Stripe) that are purely informational and require no action: move to `Payments`.
    - Subscription renewal notifications (auto-renew reminders, "will renew soon", price-change notices without a concrete transaction) are operational alerts, not payment records: move to `Deleted Messages`.
    - Installment plan activation notifications (e.g. Barclays installment purchase confirmations) are operational confirmations, not payment records: move to `Deleted Messages`.
    - "Kontoauszug verfügbar/ist online" notifications are availability alerts, not payment records: move to `Deleted Messages`.
    - Orders/invoices/business records: move to `Orders and Invoices`.
    - Shipping/tracking notifications (dispatch confirmations, carrier updates, delivery ETAs) without invoice or order-document value: move to `Deleted Messages`.
    - Marketing/newsletters: move to `Newsletters and Marketing`.
    - Delivery/submission confirmations for items you shipped outbound: move to `Outgoing Shipments`.
    - Long-term but uncategorized messages: create a concise new folder and move there.
7. Folder creation rule:
   - Create a new folder only if no existing folder fits and the message should be kept.
   - Naming constraints: concise topic name, avoid duplicates, and avoid broad catch-all names.
   - Command: `himalaya folder add "<new-folder>"`.

Document Ingestion (Paperless):
- **Purpose**: Automatically archive valuable document attachments into Paperless via its consumption directory.
- **Ingestion path**: `/var/lib/paperless/consume/inbox-triage/`
- **When to ingest**: Only for messages whose attachments have long-term archival value. Eligible categories:
  - Invoices, receipts, and billing statements (messages going to `Orders and Invoices` or `Payments`)
  - Contracts, agreements, and legal documents
  - Tax documents, account statements, and financial summaries
  - Insurance documents and policy papers
  - Official correspondence with document attachments (government, institutions)
- **When NOT to ingest**:
  - Marketing emails, newsletters, promotional material
  - Shipping/tracking notifications without invoice attachments
  - OTP codes, login alerts, password resets, ephemeral notifications
  - Subscription renewal reminders without actual invoices
  - Duplicate documents already seen in this run
  - Inline images, email signatures, logos, and non-document attachments
- **Eligible file types**: PDF, PNG, JPG/JPEG, TIFF, WEBP (documents and scans only). Skip archive files (ZIP, etc.), calendar invites (ICS), and other non-document formats.
- **Procedure**:
  1. After downloading attachments to `/tmp/himalaya-triage`, check if any are eligible documents.
  2. Copy eligible files: `cp /tmp/himalaya-triage/<filename> /var/lib/paperless/consume/inbox-triage/`
  3. If multiple messages could produce filename collisions, prefix the filename with the message ID: `<id>-<filename>`.
  4. Log each ingested file in the action log at the end of the run.
- **Conservative rule**: When in doubt whether an attachment is worth archiving, skip it. Paperless storage is cheap, but noise degrades searchability. Prefer false negatives over false positives for marketing material, but prefer false positives over false negatives for anything that looks like a financial or legal document.

Execution rules:
- Never perform bulk operations. One message ID per `read`, `move`, `delete`, and attachment command.
- Always use page size 20 for envelope listing (`-s 20`).
- If any single-ID command fails, log the error and continue with the next unreviewed ID.
- Never skip reading message content before deciding.
- Keep decisions conservative: when in doubt about whether something needs action, leave it in `INBOX`.
- Never move or delete unhandled actionable messages.
- Never move human communications that haven't been replied to, unless clearly non-actionable.
- Define "processed" as "reviewed once in this run" (including intentionally untouched human messages).
- Include only messages observed during this run's listings; if new mail arrives mid-run, leave it for the next run.
- Report a compact action log at the end with:
  - source folder,
  - total reviewed IDs,
  - counts by action (untouched/moved-to-folder/deleted),
  - per-destination-folder counts,
  - created folders,
  - documents ingested to Paperless (count and filenames),
  - short rationale for non-obvious classifications.

<user-request>
$ARGUMENTS
</user-request>
