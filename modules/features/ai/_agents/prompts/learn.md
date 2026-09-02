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
