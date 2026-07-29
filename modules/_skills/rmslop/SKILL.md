---
name: rmslop
description: Remove AI-generated slop from the current branch while preserving behavior and respecting repository conventions. Use when the user asks to run rmslop, remove AI slop, clean up generated-looking code, or simplify an agent-authored branch diff.
---

# Remove AI Slop

Compare the current branch with `origin/main` when that ref exists; otherwise compare it with `main`. Also inspect staged and unstaged changes.

Do not touch unrelated user-owned changes. If changed files fall outside the requested scope, leave them alone or ask before editing.

Remove or simplify:

- Comments that restate code, clash with nearby style, or would not help a maintainer.
- Defensive checks, invariant guards, schema decoding, or `try`/`catch` blocks that are abnormal for the area or protect states already ruled out by typed or trusted code.
- Broad casts, non-null assertions, or manual object reconstruction used only to appease the type checker.
- Throwaway helpers, types, or interfaces that add indirection without a real domain seam.
- Vague names when the surrounding domain suggests a more precise one.
- Generic abstractions, service or repository layers, mega helpers, and mocks that do not match local conventions.
- Unnecessary emoji, enthusiastic phrasing, or generated-looking prose in code, documentation, prompts, and rules.
- Lint rules with noisy patterns, missing pass/fail examples, or broad wording likely to produce false positives.
- Agent guidance that is obvious, duplicated, verbose, or session-specific.

Keep the cleanup behavior-preserving unless the slop is itself a bug. If cleanup exposes a real design decision, stop and explain the tradeoff instead of guessing.

Run validation appropriate to the files changed, following repository instructions. Report only a one-to-three-sentence summary of the cleanup.
