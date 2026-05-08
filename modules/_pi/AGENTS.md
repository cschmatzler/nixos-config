# AGENTS.md

## Version Control

- Use `git` for version control.
- Never attempt historically destructive Git commands.
- Make small, frequent commits.

## Scripting

- Use Fish (`fish`) for scripting.
- Do not use Python, Perl, Lua, awk, or any other scripting language. You are programatically blocked from doing so.

## Workflow

- Always complete the requested work.
- If there is any ambiguity about what to do next, do NOT make a decision yourself. Stop your work and ask.
- Do not end with “If you want me to…” or “I can…”; take the next necessary step and finish the job without waiting for additional confirmation.
- Do not future-proof things. Stick to the original plan.
- Do not add fallbacks or backward compatibility unless explicitly required by the user. By default, replace the previous implementation with the new one entirely.

## Validation

- Do not ignore failing tests or checks, even if they appear unrelated to your changes.
- After completing and validating your work, the final step is to run the project's full validation and test commands and ensure they all pass.
