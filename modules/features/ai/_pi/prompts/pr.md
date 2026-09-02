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
