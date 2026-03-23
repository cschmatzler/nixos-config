# AGENTS.md

## Version Control

- Use `jj` for version control, not `git`.
- `jj tug` is an alias for `jj bookmark move --from closest_bookmark(@-) --to @-`.
- Never attempt historically destructive Git commands.
- Make small, frequent commits.

## Scripting

- Use Nushell (`nu`) for scripting.
- Do not use Python, Perl, Lua, awk, or any other scripting language. You are programatically blocked from doing so.

## Validation

- Do not ignore failing tests or checks, even if they appear unrelated to your changes.
- After completing and validating your work, the final step is to run the project's full validation and test commands and ensure they all pass.

## Workflow

- Always complete the requested work.
- Do not end with “If you want me to…” or “I can…”; take the next necessary step and finish the job without waiting for additional confirmation.
