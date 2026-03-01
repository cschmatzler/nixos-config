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

Workflow:
1. Run `himalaya folder list` first and use those folders as the primary taxonomy.
2. Use this existing folder set as defaults when it fits:
   - `INBOX`
   - `Orders and Invoices`
   - `Payments`
   - `Outgoing Shipments`
   - `Newsletters and Marketing`
   - `Junk`
   - `Deleted Messages`
3. `Archive` is deprecated legacy storage:
   - Do not move new messages to `Archive`.
   - Do not create new workflows that route mail to `Archive`.
   - Existing messages already in `Archive` may remain there unchanged.
4. Determine source folder:
   - If `$ARGUMENTS` contains a folder name, use that as source.
   - Otherwise use `INBOX`.
5. Build a run scope safely:
   - List with fixed page size `20`: `himalaya envelope list -f "<source>" -p 1 -s 20`.
   - Enumerate IDs in returned order.
   - Process each ID fully before touching the next ID.
   - After each single-ID action, relist page `1` with `-s 20` and continue with the next unprocessed ID.
   - Keep an in-memory reviewed set for this run to avoid reprocessing IDs already handled or intentionally left untouched.
   - Stop when a fresh page-1 listing contains no unprocessed IDs.
6. For each single envelope ID, do all checks before any move/delete:
   - Read the message: `himalaya message read -f "<source>" <id>`.
   - If needed for classification, inspect attachments with `himalaya attachment download -f "<source>" <id>`.
   - If attachments are downloaded, inspect them and remove temporary local files after use.
7. Classification precedence (higher rule wins on conflict):
   - Human communication from an actual person: do not delete, do not move, leave untouched.
   - Clearly ephemeral automated/system message (alerts, bot/status updates, OTP/2FA, password reset codes, login codes) with no archival value: move to `Deleted Messages`.
   - Payment transaction correspondence (actual charge/payment confirmations, receipts, failed-payment notices, provider payment events such as Klarna/PayPal/Stripe): move to `Payments`.
   - Subscription renewal notifications (auto-renew reminders, "will renew soon", price-change notices without a concrete transaction) are operational alerts, not payment records: move to `Deleted Messages`.
   - "Kontoauszug verfügbar/ist online" notifications are availability alerts, not payment records: move to `Deleted Messages`.
   - Orders/invoices/business records: move to `Orders and Invoices`.
   - Shipping-only notifications: do not move to `Orders and Invoices` unless there is actual invoice/receipt/order-document value.
   - Marketing/newsletters: move to `Newsletters and Marketing`.
   - Delivery/submission confirmations: move to `Outgoing Shipments` when appropriate.
   - Long-term but uncategorized messages: create a concise new folder and move there.
8. Folder creation rule:
   - Create a new folder only if no existing folder fits and the message should be kept.
   - Naming constraints: concise topic name, avoid duplicates, and avoid broad catch-all names.
   - Command: `himalaya folder add "<new-folder>"`.

Execution rules:
- Never perform bulk operations. One message ID per `read`, `move`, `delete`, and attachment command.
- Always use page size 20 for envelope listing (`-s 20`).
- Never skip reading message content before deciding.
- Keep decisions conservative: only route clearly ephemeral automated/system messages to `Deleted Messages`.
- Never move or delete human communications via automation.
- Never route new messages to `Archive`; treat it as deprecated legacy-only.
- Define "processed" as "reviewed once in this run" (including intentionally untouched human messages).
- Include only messages observed during this run's listings; if new mail arrives mid-run, leave it for the next run.
- Report a compact action log at the end with:
  - source folder,
  - total reviewed IDs,
  - counts by action (untouched/moved-to-folder/deleted),
  - per-destination-folder counts,
  - created folders,
  - short rationale for non-obvious classifications.

<user-request>
$ARGUMENTS
</user-request>
