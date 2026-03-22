{inputs, ...}: {
	den.aspects.ai-tools.homeManager = {
		pkgs,
		inputs',
		lib,
		...
	}: {
		home.packages = [
			inputs'.llm-agents.packages.claude-code
			inputs'.llm-agents.packages.pi
			inputs'.llm-agents.packages.codex
			pkgs.cog-cli
		];

		home.file = {
			".pi/agent/extensions/pi-elixir" = {
				source = inputs.pi-elixir;
				recursive = true;
			};
			".pi/agent/extensions/pi-mcp-adapter" = {
				source = "${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter";
				recursive = true;
			};
			".pi/agent/extensions/no-git.ts".source = ./_ai-tools/no-git.ts;
			".pi/agent/extensions/no-scripting.ts".source = ./_ai-tools/no-scripting.ts;
			".pi/agent/extensions/review.ts".source = ./_ai-tools/review.ts;
			".pi/agent/extensions/session-name.ts".source = ./_ai-tools/session-name.ts;
			".pi/agent/skills/elixir-dev" = {
				source = "${inputs.pi-elixir}/skills/elixir-dev";
				recursive = true;
			};
			".pi/agent/skills/jujutsu/SKILL.md".text =
				lib.removePrefix "\n" (builtins.replaceStrings ["\t"] [""] ''
						---
						name: jujutsu
						description: Manages version control with Jujutsu (jj), including rebasing, conflict resolution, and Git interop. Use when tracking changes, navigating history, squashing/splitting commits, or pushing to Git remotes.
						---

						# Jujutsu

						Git-compatible VCS focused on concurrent development and ease of use.

						> ⚠️ **Not Git!** Jujutsu syntax differs from Git:
						>
						> - Parent: `@-` not `@~1` or `@^`
						> - Grandparent: `@--` not `@~2`
						> - Child: `@+` not `@~-1`
						> - Use `jj log` not `jj changes`

						## Key Commands

						| Command                    | Description                                  |
						| -------------------------- | -------------------------------------------- |
						| `jj st`                    | Show working copy status                     |
						| `jj log`                   | Show change log                              |
						| `jj diff`                  | Show changes in working copy                 |
						| `jj new`                   | Create new change                            |
						| `jj desc`                  | Edit change description                      |
						| `jj squash`                | Move changes to parent                       |
						| `jj split`                 | Split current change                         |
						| `jj rebase -s src -d dest` | Rebase changes                               |
						| `jj absorb`                | Move changes into stack of mutable revisions |
						| `jj bisect`                | Find bad revision by bisection               |
						| `jj fix`                   | Update files with formatting fixes           |
						| `jj sign`                  | Cryptographically sign a revision            |
						| `jj metaedit`              | Modify metadata without changing content     |

						## Basic Workflow

						```bash
						jj new                   # Create new change
						jj desc -m "feat: add feature"  # Set description
						jj log                   # View history
						jj edit change-id        # Switch to change
						jj new --before @        # Time travel (create before current)
						jj edit @-               # Go to parent
						```

						## Time Travel

						```bash
						jj edit change-id        # Switch to specific change
						jj next --edit           # Next child change
						jj edit @-               # Parent change
						jj new --before @ -m msg # Insert before current
						```

						## Merging & Rebasing

						```bash
						jj new x yz -m msg       # Merge changes
						jj rebase -s src -d dest # Rebase source onto dest
						jj abandon              # Delete current change
						```

						## Conflicts

						```bash
						jj resolve              # Interactive conflict resolution
						# Edit files, then continue
						```

						## Revset Syntax

						**Parent/child operators:**

						| Syntax | Meaning          | Example              |
						| ------ | ---------------- | -------------------- |
						| `@-`   | Parent of @      | `jj diff -r @-`      |
						| `@--`  | Grandparent      | `jj log -r @--`      |
						| `x-`   | Parent of x      | `jj diff -r abc123-` |
						| `@+`   | Child of @       | `jj log -r @+`       |
						| `x::y` | x to y inclusive | `jj log -r main::@`  |
						| `x..y` | x to y exclusive | `jj log -r main..@`  |
						| `x\|y` | Union (or)       | `jj log -r 'a \| b'` |

						**⚠️ Common mistakes:**

						- ❌ `@~1` → ✅ `@-` (parent)
						- ❌ `@^` → ✅ `@-` (parent)
						- ❌ `@~-1` → ✅ `@+` (child)
						- ❌ `jj changes` → ✅ `jj log` or `jj diff`
						- ❌ `a,b,c` → ✅ `a | b | c` (union uses pipe, not comma)

						**Functions:**

						```bash
						jj log -r 'heads(all())'        # All heads
						jj log -r 'remote_bookmarks()..'  # Not on remote
						jj log -r 'author(name)'        # By author
						jj log -r 'description(regex)'  # By description
						jj log -r 'mine()'              # My commits
						jj log -r 'committer_date(after:"7 days ago")'  # Recent commits
						jj log -r 'mine() & committer_date(after:"yesterday")'  # My recent
						```

						## Templates

						```bash
						jj log -T 'commit_id ++ "\n" ++ description'
						```

						## Git Interop

						```bash
						jj bookmark create main -r @  # Create bookmark
						jj git push --bookmark main   # Push bookmark
						jj git fetch                 # Fetch from remote
						jj bookmark track main@origin # Track remote
						```

						## Advanced Commands

						```bash
						jj absorb               # Auto-move changes to relevant commits in stack
						jj bisect start         # Start bisection
						jj bisect good          # Mark current as good
						jj bisect bad           # Mark current as bad
						jj fix                  # Run configured formatters on files
						jj sign -r @            # Sign current revision
						jj metaedit -r @ -m "new message"  # Edit metadata only
						```

						## Tips

						- No staging: changes are immediate
						- Use conventional commits: `type(scope): desc`
						- `jj undo` to revert operations
						- `jj op log` to see operation history
						- Bookmarks are like branches
						- `jj absorb` is powerful for fixing up commits in a stack

						## Related Skills

						- **gh**: GitHub CLI for PRs and issues
						- **review**: Code review before committing
					'');
			".pi/agent/themes" = {
				source = "${inputs.pi-rose-pine}/themes";
				recursive = true;
			};
			".pi/agent/settings.json".text =
				builtins.toJSON {
					theme = "rose-pine-dawn";
					quietStartup = true;
					hideThinkingBlock = true;
					defaultProvider = "openai-codex";
					defaultModel = "gpt-5.4";
					defaultThinkingLevel = "high";
					packages = [
						{
							source = "${pkgs.pi-agent-stuff}/lib/node_modules/mitsupi";
							extensions = [
								"pi-extensions/answer.ts"
								"pi-extensions/context.ts"
								"pi-extensions/multi-edit.ts"
								"pi-extensions/todos.ts"
							];
							skills = [];
							prompts = [];
							themes = [];
						}
						{
							source = "${pkgs.pi-harness}/lib/node_modules/@aliou/pi-harness";
							extensions = ["extensions/breadcrumbs/index.ts"];
							skills = [];
							prompts = [];
							themes = [];
						}
					];
				};
			".pi/agent/mcp.json".text =
				builtins.toJSON {
					mcpServers = {
						opensrc = {
							command = "npx";
							args = ["-y" "opensrc-mcp"];
						};
						context7 = {
							url = "https://mcp.context7.com/mcp";
						};
						grep_app = {
							url = "https://mcp.grep.app";
						};
						sentry = {
							url = "https://mcp.sentry.dev/mcp";
							auth = "oauth";
						};
					};
				};
		};
	};
}
