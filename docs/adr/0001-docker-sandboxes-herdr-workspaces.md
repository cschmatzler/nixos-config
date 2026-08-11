# ADR 0001: Docker Sandboxes-backed Herdr workspaces on Tahani

- Status: Accepted for trial
- Date: 2026-08-10 (revised same day after first runtime feedback)

## Context

Herdr panes normally start local shells. We want linked-worktree Herdr workspaces to run
inside isolated microVMs with real PTYs, the full host development environment (fish,
Neovim, Pi, Claude Code, Git, host secrets and MCP auth), host-visible edits, and an
Amp-orbs-style lifecycle: `.agents/setup` on creation, `.agents/resume` on wake, pause on
inactivity, cleanup on workspace closure.

Docker Sandboxes (`sbx` 0.38.0) owns the microVM, workspace passthrough, persistent guest
filesystem, network proxy, and PTY execution. Two implementation findings shape the
design:

- The `sbx` CLI burns ~3 s of CPU on every invocation, but sandboxd exposes a
  Docker-compatible engine socket whose `docker exec` attaches in ~50 ms.
- Mounting the host `/nix` store read-only lets every home-manager artifact (fish config,
  Neovim, Pi extensions, and the `pi`/`claude`/`herdr`/`node` binaries themselves) resolve
  inside the Ubuntu guest with no per-sandbox installation.
- Kit setup commands run for every sandbox; they are not a cached image layer. A prebuilt
  local template is therefore required to keep apt and browser-library installation out
  of workspace creation.

## Decision

One `shell` sandbox per linked-worktree checkout path, named `herdr-<sha256(path)>`.
Top-level workspaces get the local fish shell; classification comes from Herdr's
authoritative `worktree.is_linked_worktree`, resolved once per pane via `session.snapshot`.

**Dispatcher** (`herdr-sandbox-shell`, Herdr's `terminal.default_shell`): classifies the
workspace, attaches running sandboxes through the sandboxd Docker socket (`docker exec
-it`), falls back to `sbx exec` when the sandbox is stopped (which boots it), and creates
it when missing. After an attach ends it distinguishes user exit (sandbox still running),
pause (stopped → wait for a keypress or an external start, then re-attach), and removal
(exit).

**Guest environment**: mounts are the worktree (rw), its common Git directory (rw),
`/nix` (ro), `/run/secrets` (ro), the host Nix and Pi npm package caches (ro), the host
Playwright browser cache (ro), and the host Pi sessions directory (rw) — all at their host
paths.
Creation copies one tar stream of selected host dotfiles (fish/nvim/git/gh config, Pi agent
config + auth + MCP auth, Claude credentials, Plannotator config); symlinks inside them
resolve against the mounted store. The guest bind-mounts its worktree again at the stable
`/home/agent/workspace` path, gives every guest the stable `herdr-sandbox` hostname, and
runs lifecycle hooks there so path- and hostname-sensitive devenv and package-manager
state can move between worktrees. Before starting fish, it imports the cached devenv
environment and returns to the host-path worktree mount; Pi, Git, session
scoping, project trust, and Herdr cwd tracking therefore continue to see the real checkout
path. The guest enter script also links `~/.nix-profile` to the resolved host profile,
prepends it to `PATH`, unsets sbx's `proxy-managed` API-key and GitHub-token placeholders
(they shadow real OAuth and `gh` credentials), creates a writable Playwright registry
whose browser payloads are symlinks into
the read-only host cache, and uses a prebuilt local template for build tooling plus
Chromium and Firefox OS dependencies. The bridge prebuilds and transfers that template
from the host Docker daemon to sandboxd in the background. During lifecycle setup only,
a verified dependency snapshot gets a temporary `aube` wrapper: it runs `aube check` and
skips the redundant install only when the copied tree is consistent. A narrow `sudo`
wrapper similarly skips Playwright's apt command because the marked template already
contains those exact libraries. The guest then starts the Herdr relay and runs
`.agents/setup` once per sandbox or `.agents/resume` once per boot (detected via
`boot_id`) before exec'ing the host fish. A failed lifecycle hook is not marked complete
and is retried on a later attach.

**Bridge**: the real Herdr socket is never mounted. A loopback HTTP daemon verifies an
HMAC workspace capability, re-resolves live scope from `session.snapshot` per request,
enforces a method allowlist plus workspace/pane target scoping, and filters
cross-workspace objects from responses. A guest relay presents the Unix socket the Herdr
CLI and Pi extension expect.

**Lifecycle**: the same daemon reconciles every 30 s — a sandbox whose workspace is gone
is force-removed; a sandbox whose workspace has been unfocused for `idleMinutes` (10) with
no `working` agent is stopped. Workspaces are matched by checkout path, so Herdr restarts
(which renumber workspace ids) do not orphan sandboxes.

## Consequences

- The trial depends on Docker's proprietary `sbx` binary, its account sign-in, and the
  undocumented sandboxd Docker socket for fast attach; an sbx upgrade may require
  adjusting the attach path.
- Pane opens on a live sandbox cost one Herdr socket call plus one `docker exec`
  (sub-second). Creation uses the prebuilt template and a lightweight config tar; apt runs
  only while preparing a changed template in the background, never in workspace setup.
  New worktrees reuse
  only caches whose versioned marker matches the target's development-environment or
  dependency-input fingerprint and whose source worktree still has that fingerprint.
  Devenv's live SQLite state is copied through its backup API; dependency trees are
  hardlink-cloned and checked before their install step can be skipped. The stable guest
  path, hostname, home, and tool identity are
  included in the fingerprints. Pi installs only its `git:`-sourced packages (~3 s)
  since the npm cache is shared read-only.
- Copied credentials (Pi `auth.json`, Claude `.credentials.json`, MCP OAuth) and Pi's
  project trust decisions re-sync from the host on every pane attach, so host-side
  refreshes win; a guest-side refresh lasts only until the next attach. Read-only mounts
  (store, secrets, npm and git package caches) cannot diverge at all.
- The guest can write the mounted worktree, its common Git directory, and the shared Pi
  sessions directory; host Pi resuming a guest-written session is trusted.
- `sbx stop` kills attached execs (exit 137); panes surface a paused notice and re-attach
  on demand. Guest processes do not survive a pause.
- Sandboxd also stops sandboxes on its own once no exec remains attached, which happens
  naturally after the last pane closes.

## Rejected

- **Copying tool installations into the guest** (npm-installed Pi, curl-installed Herdr,
  apt fish/neovim): slow creation, config drift, and dangling home-manager symlinks; the
  read-only store mount removes the entire class of problem.
- **Mounting host `~/.pi/agent` or `~/.claude` read-write**: guest agents could plant code
  the host tools execute (extensions, hooks) — an escape hatch that defeats the sandbox.
- **One sandbox per pane**: panes would not share packages, services, or state.
- **Exposing the real Herdr socket**: grants cross-workspace control and host command
  surfaces.
- **A separate reaper timer unit**: the bridge daemon already holds all the state; one
  reconciler loop replaces service + timer + mapping-format coupling.
