---
description: Commit the current working tree changes
argument-hint: "[commit-message guidance]"
---

Commit the current repository changes now. Inspect `git status`, all staged and unstaged diffs, untracked files, and recent commit-message style. Run validation appropriate to the changed files unless it has already been run successfully for the same changes. Do not add generated artifacts, credentials, secrets, or clearly unrelated files.

Stage the intended current changes and create one concise commit that accurately describes them. Use any user guidance below when choosing the message. Do not amend, rebase, push, or open a pull request. If there is nothing to commit, say so. If validation fails, stop before committing and report the failure.

<commit-message-guidance>
$ARGUMENTS
</commit-message-guidance>
