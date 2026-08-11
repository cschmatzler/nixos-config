# ADR 0001: Docker Sandboxes-backed Herdr workspaces on Tahani

- Status: Accepted
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

The dispatcher copies Pi and Claude credentials, Pi's trust decisions, and the Herdr Pi
state integration into private guest storage. GitHub uses an `sbx` service secret.
Supermemory uses a sandbox-scoped custom secret registered before sandbox creation so
`sbx` injects only its placeholder. Pi sessions remain inside the guest.

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
