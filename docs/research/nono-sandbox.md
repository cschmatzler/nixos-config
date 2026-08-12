# nono sandbox research for Pi and Claude Code

Research snapshot: 2026-08-12. Primary sources were the official [`nolabs-ai/nono`](https://github.com/nolabs-ai/nono) repository and docs, official [`nolabs-ai/nono-packs`](https://github.com/nolabs-ai/nono-packs), the locked [`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix), Pi source/docs, Home Manager's Claude Code module, and this repository.

## Conclusions

### Package and platform choice

- nono supports Linux with Landlock and macOS with Seatbelt. The official installation docs explicitly include Nix via `pkgs.nono`: [installation](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/getting_started/installation.mdx).
- This repository's locked nixpkgs currently packages nono 0.71.0. Its already-locked `llm-agents.nix` input packages nono 0.73.0 for all Unix platforms: [`packages/nono/package.nix`](https://github.com/numtide/llm-agents.nix/blob/2269cbe657324760384209fd09e9c1a1c11e6e52/packages/nono/package.nix).
- Use `inputs'.llm-agents.packages.nono`, keeping nono on the same reviewed update path as Pi, Claude Code, and Plannotator. `nix run .#update -- llm-agents` advances it.
- Install on both NixOS and Darwin.

### Profiles and official plugins

Official agent packs are useful but compatibility-oriented:

- The Pi pack contributes a Pi extension and skill, denial diagnostics, and `/nono-status`: [`pi`](https://github.com/nolabs-ai/nono-packs/tree/58f77c73a949bad1a9e261bb824c51e323589984/pi).
- The Claude pack contributes a Claude personal plugin, hooks, and a denial-diagnostics skill: [`claude`](https://github.com/nolabs-ai/nono-packs/tree/58f77c73a949bad1a9e261bb824c51e323589984/claude).
- Both pack profiles include `nix_runtime`, which grants read access to `/nix/store`, profile paths, and `/run/current-system/sw`. Both leave networking open by default. Sources: [Pi policy](https://github.com/nolabs-ai/nono-packs/blob/58f77c73a949bad1a9e261bb824c51e323589984/pi/policy.json), [Claude policy](https://github.com/nolabs-ai/nono-packs/blob/58f77c73a949bad1a9e261bb824c51e323589984/claude/policy.json), [embedded groups](https://github.com/nolabs-ai/nono/blob/v0.73.0/crates/nono-cli/data/policy.json).
- `nono pull` performs signed registry installation and mutable wiring. That wiring edits `~/.pi/agent/settings.json` and Claude plugin state, conflicting with Home Manager-owned symlinks here: [pack management](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/features/managing-packs.mdx).
- Therefore pin `nolabs-ai/nono-packs` as a non-flake input and wire the reviewed plugin subdirectories through Pi's local-package support and Home Manager's supported Claude `plugins` option. `nix run .#update -- nono-packs` updates the lock; review pack policy/plugin diffs before apply. This replaces mutable registry updates with the repository's normal Nix lock and review boundary.

### Filesystem and Nix store

- nono canonicalizes paths before applying the sandbox. Home Manager links therefore require both the visible link and target runtime to be readable: [quickstart runtime sequence](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/getting_started/quickstart.mdx).
- `nix_runtime` grants read—not write—access to Nix store/profile roots. Store immutability is also enforced by Unix permissions/Nix ownership.
- On Linux, do not model “allow all of home, deny a few children.” Landlock cannot enforce deny-within-allow overlap and nono fails closed on conflicting policy. Use narrow positive grants: [profiles and groups](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/features/profiles-groups.mdx).
- The profiles need writable agent state (`~/.pi` or Claude state), Plannotator state, opensrc state, npm cache for existing runtime `npx` flows, and the current worktree. Their wrappers set `TMPDIR` to `~/.pi/tmp` or `~/.claude/tmp`, keeping Jiti and other read/write temporary artifacts inside already-granted agent state instead of exposing shared `/tmp`. SSH, cloud credentials, browser data, shell configuration/history, Docker, and other unrelated home paths remain outside the grants.
- Linked Git worktrees keep their private administrative directory and shared object/ref store under the main repository's `.git`; the linked checkout contains only a `.git` file pointing there. Git documents this as `$GIT_DIR/worktrees/<name>` plus `$GIT_COMMON_DIR`: [Git worktree details](https://github.com/git/git/blob/v2.51.0/Documentation/git-worktree.adoc#details).
- nono 0.73.0 provides `@git:common-dir`, which resolves at sandbox preparation to `.git` for a normal checkout or the main repository's absolute `.git` for a linked worktree. Use it in top-level `filesystem.allow`; upstream tests that exact form. This supports the current repository without permanently exposing another repository's metadata: [dynamic Git grants](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/features/tool-sandbox.mdx#dynamic-filesystem-grants), [top-level profile test](https://github.com/nolabs-ai/nono/blob/v0.73.0/crates/nono-cli/src/capability_ext.rs).
- Do not add `@git:worktree` or `@git:toplevel-parent` to the daily agent profile. Those are broader capabilities intended for commands that create sibling worktrees; existing-worktree Git operations need only the current workdir and `@git:common-dir`.
- nono 0.73.0's `nono why --self` state reload can reject valid sandbox state from a subprocess: `NONO_CAP_FILE` serializes process-dependent resolutions such as `/dev/stdin` to the launch PTY, `/dev/fd` to `/proc/<pi-pid>/fd`, and `/proc/self` to `/proc/<pi-pid>`, then reload validation resolves those aliases in the diagnostic subprocess and reports path drift. Granting `/dev/pts` does not fix this—the built-in Linux groups already grant it read/write—and the failure does not establish that the original command was denied. Treat it as an upstream diagnostic bug and preserve the original command's stderr: [state reload validation](https://github.com/nolabs-ai/nono/blob/v0.73.0/crates/nono-cli/src/sandbox_state.rs), [process-relative remapping](https://github.com/nolabs-ai/nono/blob/v0.73.0/crates/nono/src/capability.rs).
- Filesystem denial rules alone do not block Linux `connect(2)` to pathname Unix sockets. Set `linux.af_unix_mediation = "pathname"` so pathname sockets are default-deny unless granted through `filesystem.unix_socket*`: [Landlock pathname socket mediation](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/internals/landlock.mdx#pathname-unix-socket-mediation).
- Do not grant the Nix daemon, Docker, Herdr, D-Bus, or SSH-agent sockets by default. Any one delegates work to a host service and weakens containment. Devenv and Nix evaluation/build operations require the Nix daemon on this multi-user Nix installation, so provide an explicit `pi-nix` profile and launcher instead of weakening daily `pi`. It removes the daemon path from that variant's deny list, grants only `/nix/var/nix/daemon-socket/socket` through `filesystem.unix_socket`, and adds writable `~/.cache/nix`; Docker, Herdr, D-Bus, and SSH agent remain denied. The daemon can perform work outside nono's network/filesystem boundary, so use this elevated profile only for sessions that require Nix.

### Tool Sandbox caveat on NixOS

Do not enable nono's per-command Tool Sandbox policies in the first rollout.

The locked nixpkgs nono expression explicitly skips command-policy tests because nono's ELF resolver cannot find a Nix-store `libc.so.6` dependency through the expected search chain, noting command policies are broken on NixOS without that support: [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/279b4a8275f032c566576b3f181fa0f27197f588/pkgs/by-name/no/nono/package.nix). Upstream's resolver searches ELF runpaths plus conventional FHS directories: [`tool-sandbox/platform/linux.rs`](https://github.com/nolabs-ai/nono/blob/v0.73.0/crates/nono-cli/src/tool-sandbox/platform/linux.rs).

The outer agent sandbox remains useful and kernel-enforced without Tool Sandbox command mediation.

## Network model

nono networking is open by default. A non-empty `allow_domain` activates an authenticated supervisor HTTP proxy, blocks direct internet connections, and admits only listed hosts. `network.block = true` instead blocks all outbound networking and is unsuitable for hosted models/MCP: [networking](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/features/networking.mdx).

Plain host allowlisting uses CONNECT tunneling and preserves end-to-end TLS. URL/path rules require TLS interception. Start with hostname rules for streaming/WebSocket/SSE compatibility.

Required explicit classes:

| Class | Hosts | Reason |
|---|---|---|
| Pi OpenAI Codex | `chatgpt.com`, `auth.openai.com`, `api.openai.com` | Current default model and OAuth refresh/login |
| Claude | `api.anthropic.com`, `claude.ai`, `claude.com`, `platform.claude.com` | API and subscription/login flows |
| Executor MCP | `executor.manticore-hippocampus.ts.net` | Shared eager remote MCP endpoint |
| Supermemory | reverse-proxy route to `api.supermemory.ai` (not direct CONNECT allow) | Pi memory adapter through nono credential injection |
| npm | `registry.npmjs.org` | Existing `npx -y` MCP startup and package reconciliation |
| source retrieval | selected GitHub, PyPI, and crates hosts | opensrc and existing GitHub-backed packages/plugins |

Executor-hosted integrations need direct access only to Executor. Exa, Google Calendar, Gmail, and other integrations run behind Executor and do not need direct child egress.

Local ports are explicit: Pi's OAuth callback (1455) and Plannotator (20000).

## Environment and secrets

Without `environment.allow_vars`, nono passes every parent environment variable into the child. An explicit list clears ambient variables and restores only listed values plus nono-injected credentials: [environment filtering](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/features/environment.mdx).

Profiles should pass basic runtime, locale, terminal, XDG, certificate, editor, and explicit Pi/Claude controls. They should not inherit unrelated API keys, cloud credentials, `YNAB_API_KEY`, broad `HERDR_*`, D-Bus, or SSH-agent variables.

### Supermemory

The installed Pi Supermemory adapter accepts `SUPERMEMORY_BASE_URL` and sends `Authorization: Bearer $SUPERMEMORY_API_KEY`: [`extensions/index.ts`](https://github.com/awesamarth/pi-supermemory/blob/main/extensions/index.ts). A custom nono credential route can:

1. read `/run/secrets/supermemory-api-key` in the trusted supervisor;
2. inject a per-session phantom as `SUPERMEMORY_API_KEY`;
3. point `SUPERMEMORY_BASE_URL` to the local reverse proxy;
4. replace the phantom with the real bearer only for `api.supermemory.ai`.

This removes the real SOPS secret from the child environment.

### Pi OAuth: important residual limitation

The official `nolabs-ai/pi@0.2.0` plugin/profile does **not** broker Pi OAuth credentials. It defines static API-key routes but no OAuth `credential_providers`/`credential_routes`: [Pi policy](https://github.com/nolabs-ai/nono-packs/blob/58f77c73a949bad1a9e261bb824c51e323589984/pi/policy.json). Its `$HOME/.pi` grant makes Pi's current `auth.json` readable in the sandbox.

nono 0.73.0 does provide generic OAuth capture and documents Codex/Claude examples: [sandboxed OAuth](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/features/sandboxed-oauth-logins.mdx). It cannot be assumed safe to copy directly for Pi:

- Pi stores `access` and `refresh` under `openai-codex`.
- Pi locally parses the access token as a JWT to extract the ChatGPT account ID and then sends that same access value as the bearer credential: [Pi OAuth source](https://github.com/earendil-works/pi/blob/main/packages/ai/src/auth/oauth/openai-codex.ts).
- nono warns that JWT-shaped phantoms are for locally parsed fields that are not subsequently sent wholesale as bearer tokens.

This implementation therefore does not claim to broker or silently migrate existing Pi OAuth state. It preserves functionality with Pi's state grant and explicitly records the exposure. A safe follow-up requires a disposable Pi config directory, re-login through a Pi-specific capture profile, verification that persisted values are phantom-shaped, refresh testing, and a model call before removing access to real `auth.json`.

Claude's current profile has the analogous state-access tradeoff unless a separately validated Claude OAuth-capture migration is performed. Pi also loads `pi-claude-auth`, which reads and refreshes Claude Code's Linux credential file; the Pi profile therefore grants only the exact `~/.claude/.credentials.json` file read/write rather than granting the full Claude state directory. That credential is consequently visible to Pi and its loaded extensions.

## Security boundaries and limitations

- nono is an unprivileged same-user containment boundary, not a VM or multi-user host boundary: [security model](https://github.com/nolabs-ai/nono/blob/v0.73.0/docs/cli/internals/security-model.mdx).
- Linux permits metadata reconnaissance through operations such as `stat` even when content reads are denied.
- An explicitly allowed Unix peer can pass an already-connected socket with `SCM_RIGHTS`; socket grants are trusted channels.
- Audit is supervisor-recorded and tamper-evident within its local model, but does not attest every shared library/script/plugin in the runtime closure.
- macOS `allow_launch_services` is intentionally broad. Daily profiles should use supervised `open_urls` and reserve launch-services relaxation for setup/login.

## Validation checklist

Before making sandboxed commands the only entry points:

1. Validate generated profile JSON with `nono profile validate`.
2. Inspect allow/deny decisions with `nono why --profile ...`.
3. From disposable worktrees, confirm read/write inside CWD and denials for unrelated home files, SSH/cloud credentials, secret files, Docker/Nix/Herdr sockets, and an unlisted hostname.
4. Confirm Pi and Claude model prompts.
5. Confirm eager Executor connection and a harmless read-only Executor call.
6. Confirm opensrc starts and can retrieve sources only from listed source hosts.
7. Confirm Supermemory works while the real key is absent from child environment/files.
8. Confirm Plannotator on 20000.
9. Confirm the official nono plugins identify an intentional denial and recommend `nono why --self`.
10. Retain explicit `pi-unconfined` and `claude-unconfined` break-glass commands during rollout.

Do not enable Tool Sandbox command policies until the Nix ELF-resolution issue is fixed and separately validated.
