# NixOS Config

Personal Nix flake for four machines:

- `michael` - x86_64 Linux server
- `tahani` - x86_64 Linux home server / workstation
- `chidi` - aarch64 Darwin work laptop
- `jason` - aarch64 Darwin personal laptop

## Repository Map

- `modules/` - flake-parts modules, auto-imported via `import-tree`
- `modules/_hosts/` - host-specific submodules like hardware, disks, and services
- `modules/_lib/` - local helper functions
- `apps/` - Nushell apps exposed through the flake
- `secrets/` - SOPS-encrypted secrets
- `flake.nix` - generated flake entrypoint
- `modules/dendritic.nix` - source of truth for flake inputs and `flake.nix` generation

## How It Is Structured

This repo uses `den` and organizes configuration around aspects instead of putting everything directly in host files.

- shared behavior lives in `den.aspects.<name>.<class>` modules
- hosts are declared in `modules/hosts.nix`
- host composition happens in `modules/<host>.nix`
- user-level config mostly lives in Home Manager aspects

Common examples:

- `modules/core.nix` - shared Nix and shell foundation
- `modules/dev-tools.nix` - VCS, language, and developer tooling
- `modules/network.nix` - SSH, fail2ban, and tailscale aspects
- `modules/michael.nix` - server composition for `michael`
- `modules/tahani.nix` - server/workstation composition for `tahani`

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
