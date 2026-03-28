# NixOS Config

Personal Nix flake for four machines:

- `michael` - x86_64 Linux server
- `tahani` - x86_64 Linux home server / workstation
- `chidi` - aarch64 Darwin work laptop
- `janet` - aarch64 Darwin personal laptop

## Repository Map

- `modules/` - flake-parts modules, auto-imported via `import-tree`
- `modules/hosts/` - per-host composition modules
- `modules/hosts/_parts/` - host-private leaf modules like hardware, disks, and literal networking
- `modules/profiles/` - shared host and user profile bundles
- `modules/_lib/` - local helper functions
- `modules/_notability/`, `modules/_paperless/` - feature-owned scripts and templates
- `apps/` - Nushell apps exposed through the flake
- `secrets/` - SOPS-encrypted secrets
- `flake.nix` - generated flake entrypoint
- `modules/dendritic.nix` - source of truth for flake inputs and `flake.nix` generation

## How It Is Structured

This repo uses `den` and organizes configuration around aspects instead of putting everything directly in host files.

- shared behavior lives in `den.aspects.<name>.<class>` modules under `modules/*.nix`
- the machine inventory lives in `modules/inventory.nix`
- shared bundles live in `modules/profiles/{host,user}/`
- host composition happens in `modules/hosts/<host>.nix`
- host-private imports live in `modules/hosts/_parts/<host>/` and stay limited to true machine leaf files
- feature-owned services live in top-level modules like `modules/gitea.nix`, `modules/notability.nix`, and `modules/paperless.nix`
- user-level config mostly lives in Home Manager aspects

Common examples:

- `modules/core.nix` - shared Nix and shell foundation
- `modules/dev-tools.nix` - VCS, language, and developer tooling
- `modules/network.nix` - SSH, fail2ban, and tailscale aspects
- `modules/gitea.nix` - Gitea, Litestream, and backup stack for `michael`
- `modules/notability.nix` - Notability ingest services and user tooling for `tahani`
- `modules/profiles/user/workstation.nix` - shared developer workstation user bundle
- `modules/hosts/michael.nix` - server composition for `michael`
- `modules/hosts/tahani.nix` - server/workstation composition for `tahani`

## Common Commands

```bash
nix run .#build
nix run .#build -- michael
nix run .#apply
nix run .#deploy -- .#tahani
nix flake check
alejandra .
```

## Updating The Flake

`flake.nix` is generated. Update inputs in `modules/dendritic.nix`, then regenerate:

```bash
nix run .#write-flake
alejandra .
```
