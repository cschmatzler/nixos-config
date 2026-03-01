---
description: Triage inbox one message at a time with himalaya only
---

Process email with strict manual triage using Himalaya only.

Hard requirements:
- Use `himalaya` for every mailbox interaction (folders, listing, reading, moving, deleting, attachments).
- Process exactly one message at a time. Never run bulk actions on multiple IDs.
- Do not use pattern-matching commands or searches (`grep`, `rg`, `awk`, `sed`, `himalaya envelope list` query filters, etc.).
- Always inspect current folders first, then triage.

Workflow:
1. Run `himalaya folder list` first and use those folders as the primary taxonomy.
2. Use this existing folder set as defaults when it fits:
   - `INBOX`
   - `Orders and Invoices`
   - `Payments`
   - `Einlieferungen`
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
5. List envelopes in explicit pages of 20 from the source folder without search filters.
   - Use: `himalaya envelope list -f "<source>" -p <page> -s 20`.
   - Start at page `1`.
   - Work page-by-page in ascending order.
6. For each page:
   - Enumerate IDs in the returned order.
   - Process each single envelope ID fully before touching the next ID.
   - Do not request the next page until every ID from the current page is finished.
7. For each single envelope ID, do all checks before any move/delete:
   - Read the message (`himalaya message read -f "<source>" <id>`).
   - If needed for classification, inspect attachments with Himalaya (`himalaya attachment download -f "<source>" <id>`), then reason from the attachment names/content.
8. Classify and act for that one ID:
   - Ephemeral communication from automated/system senders (alerts, bot/status updates, auth/login codes, OTP/2FA verification emails, password-reset codes, no archival value): delete it.
   - Communication from actual people: do not delete, do not move, and do not auto-triage; leave untouched in the current folder (typically `INBOX`).
   - Orders/invoices: move only real order/invoice/business records to `Orders and Invoices`.
   - Payments: move payment confirmations, payment reminders, and payment-provider messages (e.g. Klarna, PayPal, Stripe) to `Payments`. Do not confuse with order confirmations or invoices — `Payments` is specifically for payment-transaction correspondence.
   - Shipping-only notifications: do not move to `Orders and Invoices` unless there is actual invoice/receipt/order-document value (for example, invoice attached or embedded billing document).
   - Marketing/newsletters: move to `Newsletters and Marketing`.
   - Delivery/submission confirmations (`Einlieferungen`) when appropriate.
   - Long-term but uncategorized messages: create a new folder and move there.
9. Folder creation rule:
   - If none of the existing folders fit but the message should be kept, create a concise new folder with `himalaya folder add "<new-folder>"`, then move the message there.
10. Continue until all messages in source folder are processed:
   - After a page is completely processed, request the next page (`-p <page+1>`) with the same page size (`-s 20`).
   - Stop only when there are no more envelopes to process.

Execution rules:
- Never perform bulk operations. One message ID per `read`, `move`, `delete`, and attachment command.
- Never query page `N+1` before fully processing page `N`.
- Always use page size 20 for envelope listing (`-s 20`).
- Never skip reading message content before deciding.
- Keep decisions conservative: delete only clearly ephemeral automated/system messages.
- Never move or delete human communications via automation.
- Never route new messages to `Archive`; treat it as deprecated legacy-only.
- Report a compact action log at the end: per-folder counts, created folders, and a short rationale for non-obvious classifications.

<user-request>
$ARGUMENTS
</user-request>
