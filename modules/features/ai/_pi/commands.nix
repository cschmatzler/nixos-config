{
  learn = ''
    ---
    description: Capture session learnings in Supermemory or repository enforcement
    argument-hint: "[focus or recent-session count]"
    ---

    Analyze this session and turn non-obvious learnings into durable project knowledge or enforcement.

    Prefer the narrowest durable home:

    - Project-scoped Supermemory is the default for stable debugging discoveries, tool quirks, module relationships, operational context, and day-to-day guidance that does not need deterministic injection on every turn.
    - User-scoped Supermemory is only for durable preferences or workflows that apply across projects.
    - Keep `AGENTS.md` minimal. Add guidance there only when every agent must receive it deterministically, especially safety boundaries, command restrictions, or costly mutation constraints that should not depend on memory retrieval.
    - Use `.taskless/rules/` plus `.taskless/rule-tests/` for repeatable structural patterns that ast-grep can enforce.
    - Use `packages/oxlint-plugins/` and `oxlint.config.ts` when enforcement needs TypeScript-aware linting, cross-node logic, type-ish context available to Oxlint JS plugins, or editor/lint integration.
    - Use existing docs or ADRs for architectural decisions that maintainers should review explicitly.

    What counts as a learning:

    - Hidden relationships between files or modules.
    - Execution paths that differ from how the code first appears.
    - Non-obvious configuration, environment variables, flags, or command restrictions.
    - Debugging breakthroughs where errors were misleading.
    - API or tool quirks and workarounds.
    - Build/test validation gotchas not already captured.
    - Architectural constraints and files that must change together.
    - Repeated review feedback precise enough for mechanical enforcement.

    Do not capture:

    - Obvious documentation or standard framework behavior.
    - Anything already represented canonically in current Supermemory, scoped `AGENTS.md`, Taskless/Oxlint, README, docs, or ADRs.
    - Session-specific status, transient versions or command output, one-off mistakes, credentials, secrets, private reasoning, or raw transcripts.
    - Subjective lint rules without a clear recurring pattern and realistic pass/fail examples.
    - Superseded decisions from old sessions without checking them against the current repository.

    Process:

    1. Start with the current session. When the focus requests prior sessions, inspect `PI_SESSION_FILE` to locate this project's session directory and review the requested number of most-recent top-level session JSONL files, counting the current session first. Exclude nested subagent runs unless they contain distinct evidence, and deduplicate forked/delegated copies of the same task.
    2. Before placing prior-session content in model context, use Pi's `SessionManager.buildContextEntries()` when available or reconstruct the active branch by following the current leaf's `parentId` chain. Filter that branch through a local parser to user/assistant text and relevant compaction or branch summaries; never dump or read the whole JSONL into context. Exclude thinking blocks, tool payloads, secret-bearing output, and whole transcripts.
    3. Validate each candidate against current source, history, existing guidance/rules/docs, and current project/user memories. Current tracked code wins over stale session claims or memories.
    4. Search Supermemory before every save. Prefer one concise, searchable canonical memory over synonyms; use project scope unless the learning truly applies across projects. Remove or replace a stale memory only when current evidence clearly contradicts it; before forgetting, run an exact scoped search/preview, then verify the intended memory is gone afterward.
    5. If trimming `AGENTS.md`, first ensure removed contextual guidance is already represented by current enforcement/docs or migrate it into canonical project memories. Retain only the smallest deterministic safety and execution contract.
    6. For Taskless changes, follow the `taskless` skill and add/update pass and fail rule tests. For Oxlint changes, inspect the existing plugin shape and add matching coverage.
    7. Keep any `AGENTS.md` entry to 1-3 lines and rules precise enough to avoid noisy false positives.
    8. Run validation relevant to repository files changed. Supermemory-only updates do not require repository checks.

    At the end, summarize memories saved, stale memories removed, and repository files created or updated, with a short reason for each.

    Focus: $ARGUMENTS
  '';
  commit = ''
    ---
    description: Commit the current working tree changes
    argument-hint: "[commit-message guidance]"
    ---

    Commit the current repository changes now. Inspect `git status`, all staged and unstaged diffs, untracked files, and recent commit-message style. Run validation appropriate to the changed files unless it has already been run successfully for the same changes. Do not add generated artifacts, credentials, secrets, or clearly unrelated files.

    Stage the intended current changes and create one concise commit that accurately describes them. Use any user guidance below when choosing the message. Do not amend, rebase, push, or open a pull request. If there is nothing to commit, say so. If validation fails, stop before committing and report the failure.

    <commit-message-guidance>
    $ARGUMENTS
    </commit-message-guidance>
  '';
  pr = ''
    ---
    description: Commit, push, and create or update the current pull request
    argument-hint: "[PR guidance]"
    ---

    Finish the current branch as a pull request now.

    1. Inspect the repository status, staged and unstaged diffs, untracked files, branch history, remote configuration, and the full branch diff against its base.
    2. Run validation appropriate to the changed files unless it has already been run successfully for the same changes. Stop and report the failure if validation does not pass.
    3. If the working tree has intended changes, stage them and create one concise commit following the repository's commit-message style. Do not amend or rebase. Do not commit generated artifacts, credentials, secrets, or clearly unrelated files.
    4. Push the current branch to its upstream, setting the upstream when needed. Never force-push.
    5. Use `gh` to detect whether the current branch already has a pull request.
       - If one exists, update its title and body so they accurately summarize the complete current branch diff, then report its URL. The pushed commits must update that same pull request; do not create another one.
       - If none exists, create a pull request against the repository's default base branch with an accurate title and body, then report its URL.
    6. The PR body must concisely explain the change and include the validation performed. Follow any repository PR template when present.

    Do not merely print suggested commands: perform the commit, push, and PR create/update operations. If the current branch is the default branch or is detached, stop before committing or pushing and explain what must be fixed.

    <pr-guidance>
    $ARGUMENTS
    </pr-guidance>
  '';
  rmslop = ''
    ---
    description: Remove generated-looking code from the current branch while preserving behavior
    argument-hint: "[scope]"
    ---
    Clean up AI-generated slop in the current branch while preserving behavior and following repository conventions.

    Compare the branch with `origin/main` when available, otherwise `main`, and inspect staged and unstaged changes. Remove unnecessary commentary, abnormal defensive code, type-system workarounds, needless indirection, vague names, generic abstractions, generated-looking prose, and other changes that do not fit the surrounding code. Do not touch unrelated user-owned changes. Stop and explain rather than guessing when cleanup exposes a real design decision.

    Run validation appropriate to the changed files and report the cleanup in no more than three sentences.

    <scope>
    $ARGUMENTS
    </scope>
  '';
  "albanian-lesson" = ''
    Process the pasted Albanian lesson content and create two `zk` notes: one for lesson material and one for exercises.

    <lesson-material>
    $ARGUMENTS
    </lesson-material>

    Requirements:

    1. Parse the lesson content and produce two markdown outputs:
       - `material` output: lesson material only.
       - `exercises` output: exercises and solutions.
    2. Use today's date in both notes (date in title and inside content).
    3. In the `material` output:
       - Keep clean markdown structure with headings and bullet points.
       - Do not add a top-level title heading (no `# ...`) because `zk new --title` already sets the note title.
       - Translate examples, dialogues, and all lesson texts into English when not already translated.
       - For bigger reading passages, include a word-by-word breakdown.
       - For declension/conjugation/grammar tables, provide a complete table of possibilities relevant to the topic.
       - Spell out numbers only when the source token is Albanian; do not spell out English numbers.
    4. In the `exercises` output:
       - Include every exercise in markdown.
       - Do not add a top-level title heading (no `# ...`) because `zk new --title` already sets the note title.
       - Translate each exercise to English.
       - Solve all non-free-writing tasks (multiple choice, fill in the blanks, etc.) and include example solutions.
       - For free-writing tasks, provide expanded examples using basic vocabulary from the lesson (if prompted for 3, provide 10).
       - Translate free-writing example answers into English.
       - Spell out numbers only when the source token is Albanian; do not spell out English numbers.

    Execution steps:

    1. Generate two markdown contents in memory (do not create temporary files):
       - `MATERIAL_CONTENT`
       - `EXERCISES_CONTENT`
    2. Set `TODAY="$(date +%F)"` once and reuse it for both notes.
    3. Create note 1 with `zk` by piping markdown directly to stdin:
       - Title format: `Albanian Lesson Material - YYYY-MM-DD`
       - Command pattern:
         - `printf "%s\n" "$MATERIAL_CONTENT" | zk new --interactive --title "Albanian Lesson Material - $TODAY" --date "$TODAY" --print-path`
    4. Create note 2 with `zk` by piping markdown directly to stdin:
       - Title format: `Albanian Lesson Exercises - YYYY-MM-DD`
       - Command pattern:
         - `printf "%s\n" "$EXERCISES_CONTENT" | zk new --interactive --title "Albanian Lesson Exercises - $TODAY" --date "$TODAY" --print-path`
    5. Print both created note paths and a short checklist of what was included.

    If no lesson material was provided in `$ARGUMENTS`, stop and ask the user to paste it.
  '';
  "inbox-triage" = ''
    Process email with strict manual triage using Himalaya only.

    Hard requirements:
    - Use `himalaya` for every mailbox interaction (folders, listing, reading, moving).
    - Process exactly one message ID at a time. Never run bulk actions on multiple IDs.
    - Do not use pattern-matching commands or searches (`grep`, `rg`, `awk`, `sed`, `himalaya envelope list` query filters, etc.).
    - Always inspect current folders first, then triage.
    - Treat this as a single deterministic run over a snapshot of message IDs discovered during this run.

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
    5. For each single envelope ID, do all checks before any move:
       - Check envelope flags from the JSON listing (seen/answered/flagged) before reading.
       - Read the message: `himalaya message read -f "<source>" <id>`.
       - Move: `himalaya message move -f "<source>" "<destination>" <id>`.
       - Do not call `himalaya message delete`; trash messages by moving them to `Deleted Messages`.
    6. Classification precedence (higher rule wins on conflict):
       - **Actionable and unhandled** - if the message needs a reply, requires manual payment, needs a confirmation, or demands any human action, AND has NOT been replied to (no `answered` flag), leave it in the source folder untouched. This is the highest-priority rule: anything that still needs attention stays in `INBOX`.
       - Human correspondence already handled - freeform natural-language messages written by a human that have been replied to (`answered` flag set): move to `Correspondence`.
       - Human communication not yet replied to but not clearly actionable - when in doubt whether a human message requires action, leave it untouched.
       - Obvious spam, phishing, or unsolicited scam messages: move to `Junk`.
       - Clearly ephemeral automated/system message (alerts, bot/status updates, OTP/2FA, password reset codes, login codes) with no archival value: move to `Deleted Messages`.
       - Automatic payment transaction notifications (charge/payment confirmations, receipts, failed-payment notices, provider payment events such as Klarna/PayPal/Stripe) that are purely informational and require no action: move to `Payments`.
       - Subscription renewal notifications (auto-renew reminders, "will renew soon", price-change notices without a concrete transaction) are operational alerts, not payment records: move to `Deleted Messages`.
       - Installment plan activation notifications (for example, Barclays "Ihr Ratenkauf wurde aktiviert") are operational confirmations, not payment records: move to `Deleted Messages`.
       - "Kontoauszug verfuegbar/ist online" notifications are availability alerts, not payment records: move to `Deleted Messages`.
       - Orders/invoices/business records: move to `Orders and Invoices`.
       - Shipping/tracking notifications (dispatch confirmations, carrier updates, delivery ETAs) without invoice or order-document value: move to `Deleted Messages`.
       - Marketing/newsletters: move to `Newsletters and Marketing`.
       - Delivery/submission confirmations for items you shipped outbound: move to `Outgoing Shipments`.
       - Long-term but uncategorized messages: create a concise new folder and move there.
    7. Folder creation rule:
       - Create a new folder only if no existing folder fits and the message should be kept.
       - Naming constraints: concise topic name, avoid duplicates, and avoid broad catch-all names.
       - Command: `himalaya folder add "<new-folder>"`.

    Execution rules:
    - Never perform bulk operations. One message ID per `read` and `move` command.
    - Always use page size 20 for envelope listing (`-s 20`).
    - If any single-ID command fails, log the error and continue with the next unreviewed ID.
    - Never skip reading message content before deciding.
    - Keep decisions conservative: when in doubt about whether something needs action, leave it in `INBOX`.
    - Never move unhandled actionable messages.
    - Never move human communications that haven't been replied to, unless clearly non-actionable.
    - Define "processed" as "reviewed once in this run" (including intentionally untouched human messages).
    - Include only messages observed during this run's listings; if new mail arrives mid-run, leave it for the next run.
    - Report a compact action log at the end with:
      - source folder,
      - total reviewed IDs,
      - counts by action (untouched/moved-to-folder),
      - per-destination-folder counts,
      - created folders,
      - short rationale for non-obvious classifications.

    <user-request>
    $ARGUMENTS
    </user-request>
  '';
}
