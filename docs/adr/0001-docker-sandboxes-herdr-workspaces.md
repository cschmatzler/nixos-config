# ADR 0001: Docker Sandboxes-backed Herdr workspaces on Tahani

- Status: Accepted
- Date: 2026-08-10
- Revised: 2026-08-11

## Context

Herdr starts panes through one configured shell command. Linked-worktree workspaces should
run Pi inside Docker Sandboxes, while top-level workspaces should remain local. The guest
needs the Home Manager Fish environment, Pi credentials and package caches, and scoped
access to its own Herdr workspace.

Docker Sandboxes already owns guest creation, private Git clones, persistence, resource
limits, network policy, and attachment. Reimplementing those responsibilities creates a
second sandbox controller with different lifecycle and security rules.

## Decision

A small Fish dispatcher is Herdr's default shell.

- A top-level Herdr workspace directly opens the local Home Manager Fish.
- A linked-worktree workspace maps deterministically to one `sbx` shell sandbox.
- The dispatcher creates missing guests with `sbx create --clone` and attaches with
  `sbx exec`.
- Because `sbx --clone` rejects linked worktrees, it clones the main repository and
  selects the linked worktree's branch inside the private clone.
- Git isolation and publication use Docker Sandboxes' clone mode. Host Git exposes the
  guest's commits through the `sandbox-<name>` remote supplied by `sbx`.

The guest launches Fish from the read-only host Nix profile. It mirrors the current Home
Manager generation as read-only links under `/home/agent`, giving Fish and Pi their normal
configuration without mounting the host home directory. Before opening Fish, it runs the
repository's `.agents/resume` contract and falls back to `.agents/setup` when the working
copy is not ready.

Only established caches are added as read-only `sbx` workspace mounts:

- `/nix`
- Pi npm and Git package caches
- the Nix cache
- the Playwright browser cache

There is no custom cache fingerprinting, copying, hardlinking, reflinking, or overlay
policy. Sandbox persistence and the mounted caches provide reuse.

The dispatcher copies Pi OAuth and MCP credential files and Herdr's Pi state integration
into the guest's private home on attachment. GitHub and Supermemory use sandbox-scoped
Docker Sandbox proxy secrets. Pi sessions remain private to the sandbox.

The kit extends Docker Sandboxes' shell policy with the endpoints required by Nix and
Devenv, Pi's model provider, the configured MCPs, Supermemory, and the local Herdr broker.
Other egress remains denied by the sandbox network policy.

The real Herdr socket is never mounted. A host broker accepts a random capability written
by the dispatcher, derives live workspace authority from Herdr for every request, removes
unsafe launch environment values, scopes targets and responses to that workspace, and
forwards allowed RPC calls. A small guest relay presents the Unix socket expected by the
Herdr CLI and `pi-herdr`.

Docker Sandboxes remains authoritative for Git, filesystem isolation, networking,
lifecycle, and sandbox cleanup. The integration does not call the sandboxd Docker socket
or maintain a parallel reconciler.

## Consequences

- Uncommitted guest edits live in the private clone rather than the host linked worktree.
  Commits are retrieved through the `sbx`-managed remote.
- The hot path invokes `sbx exec`; no custom Docker fast path is maintained.
- Cache behavior follows `sbx` plus the four explicit read-only cache mounts.
- Pi credentials are intentionally available to Pi processes inside the guest. They are
  not mounted back into the host and do not grant access to unrelated host files.
- Herdr API compatibility remains the only custom protocol integration.

## Rejected

- A TypeScript sandbox shell client, lifecycle reconciler, or direct sandboxd Docker API.
- Custom Git mounts, wrappers, ref publication, or worktree synchronization.
- Custom template images, privileged root helpers, hostname changes, and sudo wrappers.
- Cross-worktree dependency and devenv cache cloning.
- Mounting the real Herdr socket or the writable host Pi session directory.
