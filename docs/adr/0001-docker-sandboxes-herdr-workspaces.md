# ADR 0001: Docker Sandboxes-backed Herdr workspaces on Tahani

- Status: Superseded by [ADR 0002](./0002-microvm-nix-herdr-workspaces.md)
- Date: 2026-08-10
- Revised: 2026-08-11

## Context

Herdr uses one configured shell command for new panes. Linked-worktree workspaces should
run inside Docker Sandboxes with the user's Fish and Pi configuration, while top-level
workspaces should remain local.

Docker Sandboxes already provides private Git clones, persistence, resource limits,
network policy, and attachment. The integration should not duplicate that lifecycle.

## Decision

Herdr uses a Fish dispatcher that:

- opens top-level workspaces in the local Home Manager Fish;
- maps each linked worktree to one deterministic `sbx` shell sandbox;
- clones the main checkout because `sbx --clone` rejects linked worktrees, then selects
  the linked worktree's branch;
- bind-mounts the private clone at the linked checkout path so Fish and Devenv resolve the
  same project root; and
- leaves Git isolation and commit publication to `sbx` clone mode.

The guest uses the read-only host Nix profile and Home Manager generation under
`/home/agent`. It runs `.agents/resume`, falling back to `.agents/setup`, before opening
Fish. The only additional read-only mounts are `/nix`, Pi's npm and Git caches, the Nix
cache, and the Playwright browser cache.

Pane attach is a single `sbx exec`; every `sbx` CLI invocation scrypt-decrypts the whole
secret store (~0.35s per entry) plus fixed startup cost, so per-pane work is stamped
away. A host stamp (`state/provisioned/<sandbox>`, containing a digest of the kit store
path and credential mtimes) gates creation checks and the credential/guest-script sync;
after `sbx rm <sandbox>`, remove its stamp too. The guest gates the Home Manager symlink
mirror per generation and `.agents/resume` per VM boot, and re-establishes the checkout
bind-mount itself via passwordless sudo (mounts do not survive sandbox restarts).

The dispatcher copies Pi and Claude credentials, Pi's trust decisions, and the Herdr Pi
state integration into private guest storage; the same sync stream carries the guest
scripts, so existing sandboxes pick up script changes without a kit version bump.
GitHub and Supermemory use global `sbx` secrets — one store entry each instead of one
per sandbox, because every entry slows every CLI call — and `sbx` injects only the
Supermemory placeholder. Pi sessions remain inside the guest.

The kit allows only the endpoints required by Nix, Devenv, the configured model
providers and MCPs, GitHub, Supermemory, and the local Herdr broker.

The host Herdr socket is never mounted. A host broker authenticates a random sandbox
capability, derives its scope from live Herdr state, rejects out-of-scope operations,
passes Herdr error responses through unchanged, and filters global responses. A guest
relay exposes the Unix socket expected by the Herdr CLI and `pi-herdr`. The capability
reaches the guest as `sbx exec` environment; `sbx exec --env-file` (0.38.0) parses but
silently drops the variables, so the token stays on the exec command line.

Herdr starts pane agents only in panes whose host-side foreground process is named like
a shell, so the interactive attach execs `sbx` through a fish-named path. Sandboxed
agents therefore start through Herdr's native `agent.start`, with launch readiness
driven by the guest's reported agent state.

## Consequences

- Uncommitted guest edits remain in the private clone; commits are retrieved through the
  `sbx`-managed remote.
- Sandbox persistence and the four read-only cache mounts provide reuse.
- Pi and Claude credentials are available inside the guest but are not mounted back into
  the host.
- Herdr API compatibility is the only custom protocol boundary.

## Rejected

- A second sandbox lifecycle controller or direct sandboxd Docker API.
- Custom Git publication, worktree synchronization, or cache replication.
- Custom images, privileged guest helpers, or mounting the host Herdr socket.
- Mounting writable host Pi sessions into the guest.
