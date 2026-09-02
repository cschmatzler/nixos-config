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
