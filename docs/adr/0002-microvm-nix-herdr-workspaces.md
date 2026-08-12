# ADR 0002: microvm.nix-backed Herdr workspaces on Tahani

- Status: Accepted
- Date: 2026-08-11
- Supersedes: [ADR 0001](./0001-docker-sandboxes-herdr-workspaces.md)

## Context

Docker `sbx` imposes seconds of CLI startup and secret-store decryption on every pane
attach. A measured cloud-hypervisor spike attached a warm PTY Fish in about 340 ms,
ran four independent VMs from one runner with the same configured CID, preserved the
guest-kernel boundary, and was accepted by Herdr strongly enough to launch Pi.

The replacement must retain deterministic per-worktree environments, a private
persistent checkout at the host checkout pathname, Ubuntu and `apt`, inner Docker,
read-only host tooling and caches, scoped Herdr access, credential isolation,
fail-closed egress, native Herdr agent startup, and the existing resource sizes.

## Decision

Herdr linked-worktree panes use one shared microvm.nix runner with cloud-hypervisor.
Each deterministic `herdr-<20 hex>` instance has a 20 GiB persistent root image and a
20 GiB Docker image, 4 vCPUs, and 8 GiB of guest memory. The guest has no network
interface. The NixOS control guest runs a persistent Ubuntu 24.04 systemd-nspawn
environment so the interactive workspace retains Ubuntu, `apt`, and the host Home
Manager profile while the security boundary remains the MicroVM guest kernel.

The host uses fixed-runner systemd template units. Root-run virtiofsd never executes a
user-selected `current` symlink. The desktop user may manage only validated
`herdr-[0-9a-f]{20}` units through polkit. Images and runtime sockets are owned by the
`microvm` user; the fixed runner is rooted by the host system closure.

The checkout is seeded once by streaming a Git bundle over vsock SSH into the private
root image. It is bind-mounted inside Ubuntu at the exact host checkout path. The host
repository receives a deterministic, read-only `herdr::<id>` remote whose transport
uses `git-upload-pack` over the same vsock SSH channel. The guest never receives a
writable host checkout or permission to update live host refs.

The host `/nix/store` and the four existing caches are read-only tuned virtiofs shares.
Pi and Claude credentials, the scoped Herdr capability, and guest scripts are transferred
over SSH stdin into guest-private storage. GitHub and Supermemory retain proxy-side
credential injection: the guest receives fixed phantom tokens, while local guest gateways
route their clients through host-side nono credential routes. The capability is read from
a mode-0600 file rather than appearing in host or guest command arguments.

Guest-to-host cloud-hypervisor vsock listeners carry two protocols:

- the existing capability-authenticated Herdr broker; and
- an HTTP proxy path with an exact host-and-port gate in front of `nono proxy`.

The guest has no alternate route, so proxy failure denies egress. Nono retains DNS,
private-address, metadata, and rebinding enforcement while the gate preserves ADR
0001's explicit port restrictions.

Pane attachment execs a real SSH binary copied to a Nix-store path named `fish`, which
preserves Herdr's available-shell detection. SSH uses a per-workspace host-key alias and
persistent known-hosts file. The Ubuntu entrypoint retains Home Manager mirroring, OSC
7 host identity, environment home remapping, Playwright cache behavior, the Herdr agent
state relay, and once-per-VM-boot `.agents/resume` with `.agents/setup` fallback.

## Consequences

- Warm pane attachment no longer invokes `sbx` or decrypts a global secret store.
- A first workspace boot still includes MicroVM and Ubuntu-container startup; persistent
  SSH host keys remove the spike's per-boot key generation.
- Guest root and Docker state are explicitly bounded and persistent.
- Git publication is pull-only from the host's perspective and cannot mutate a checked
  out host branch.
- The custom protocol surface remains the scoped Herdr broker, plus a small exact
  endpoint gate in front of nono.
- Existing Docker Sandbox state is not read, imported, or retained by the implementation.

## Rejected

- Retaining `sbx` as a fallback or selectable backend.
- A compatibility layer for old sandbox names, stamps, secrets, or state.
- Bubblewrap or another shared-kernel backend.
- User-writable runner symlinks consumed by root virtiofsd.
- Writable host checkout, home, Docker socket, SSH agent, or credential shares.
- Tap networking, unrestricted SLiRP, environment-only proxy enforcement, or a
  hostname allowlist that drops port restrictions.
- Guest pushes into live host refs.
