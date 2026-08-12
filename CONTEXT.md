# Nix Configuration

This context describes the vocabulary used to compose and operate the repository's personal multi-host Nix configuration.

## Language

### Composition

**Host**:
A named machine declared in the inventory and composed by one host Aspect.
_Avoid_: Machine configuration, node

**Aspect**:
A den Module that owns one cohesive capability or one Host composition across its applicable platform classes.
_Avoid_: Feature flag, mixin

**Profile**:
An include-only Aspect that groups capabilities into a reusable host or user role.
_Avoid_: Preset, bundle

**Capability**:
A reusable behavior owned by a feature Aspect and selected through Host or Profile composition.
_Avoid_: Feature, package group

### Operations and integrations

**Lifecycle Command**:
A flake application that builds, applies, updates, or rolls back configuration.
_Avoid_: Script, utility

**Tailscale Serve Exposure**:
A named Tailscale Serve mapping from an HTTPS identity to a local workload, which may be a systemd unit or a Pi plugin.
_Avoid_: Proxy service, tunnel

**Plannotator Pi Plugin**:
The Pi plugin that owns Plannotator's local listener and its Tailscale Serve Exposure.
_Avoid_: Plannotator systemd unit

**AI Tool Inventory**:
The commands, skills, and MCP endpoints intentionally made available through one or more AI tool Adapters.
_Avoid_: Shared AI config, tool list

**Syncthing Desired State**:
The declared devices, folders, and options that Syncthing must reconcile, including deletion of undeclared devices and folders.
_Avoid_: Syncthing config blob, sync settings

**Workspace PR Status**:
The last successfully resolved pull request identity, mergeability, and CI state reported for a Herdr workspace.
_Avoid_: PR metadata, sidebar tokens

**Sandboxed Herdr Workspace**:
One linked-worktree Herdr workspace whose panes share a single isolated guest and its private working copy. Top-level Herdr workspaces remain local.
_Avoid_: Sandboxed pane, remote shell

**Herdr Capability Broker**:
The host boundary that derives a sandbox's Herdr scope from live ownership and exposes only authorized Herdr operations without revealing the real socket.
_Avoid_: Socket proxy, Herdr gateway

**Docker Sandbox Backend**:
The `sbx`-managed microVM provider that owns guest storage, networking, Docker Engine isolation, workspace passthrough, and PTY execution for a Sandboxed Herdr Workspace.
_Avoid_: Docker container, custom VM controller

## Relationships

- A **Host** is declared once in the inventory and composed by exactly one host **Aspect**.
- An **Aspect** may include zero or more **Profiles**, **Capabilities**, or other **Aspects**.
- A **Profile** groups one or more **Capabilities** without owning Host identity.
- A **Lifecycle Command** operates on one **Host** or on the flake that declares the Hosts.
- A **Tailscale Serve Exposure** belongs to one local workload and preserves its configured HTTPS identity.
- The **Plannotator Pi Plugin** owns the Plannotator **Tailscale Serve Exposure** without introducing a fictitious systemd workload unit.
- The **AI Tool Inventory** is translated by the Pi and Claude Code Adapters with explicit membership per Adapter.
- **Syncthing Desired State** is consumed declaratively on NixOS and reconciled through local HTTP on Darwin.
- **Workspace PR Status** remains unchanged when directory, Git, or GitHub lookup is unavailable and is cleared when Git confirms no branch or GitHub confirms no pull request.
- A linked-worktree **Sandboxed Herdr Workspace** owns one Docker Sandbox and private working copy shared by all of its panes; top-level Herdr workspaces intentionally use the local shell.
- The **Herdr Capability Broker** derives pane and workspace authority from the real Herdr state rather than trusting caller-provided identifiers.
- The **Docker Sandbox Backend** supplies one persistent guest per **Sandboxed Herdr Workspace**, while Herdr remains authoritative for workspace lifetime.

## Example dialogue

> **Dev:** "Which workload owns the Plannotator **Tailscale Serve Exposure**?"
> **Domain expert:** "The **Plannotator Pi Plugin** owns it; do not invent a separate systemd workload unit."
>
> **Dev:** "Must every entry in the **AI Tool Inventory** appear in both Adapters?"
> **Domain expert:** "No. Membership is explicit because some commands belong only to Pi or Claude Code."
