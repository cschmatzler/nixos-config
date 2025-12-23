# AGENTS.md

## ⚠️ VERSION CONTROL: JUJUTSU (jj) ONLY
**NEVER run git commands.** This repo uses Jujutsu (`jj`). Use `jj status`, `jj diff`, `jj commit`, etc.

## Build Commands
```bash
nix run .#build               # Build current host config
nix run .#build -- <hostname> # Build specific host (chidi, jason, michael, mindy, tahani)
nix run .#apply               # Build and apply locally (darwin-rebuild/nixos-rebuild switch)
nix flake check               # Validate flake

# Remote NixOS deployment (colmena)
colmena build                 # Build all NixOS hosts
colmena apply --on <host>     # Deploy to specific NixOS host (michael, mindy, tahani)
colmena apply                 # Deploy to all NixOS hosts
```

## Code Style
- **Formatter**: Alejandra with tabs (run `alejandra .` to format)
- **Function args**: Destructure on separate lines `{inputs, pkgs, ...}:`
- **Imports**: Use relative paths from file location (`../../profiles/foo.nix`)
- **Attribute sets**: One attribute per line, trailing semicolons
- **Lists**: `with pkgs; [...]` for packages, one item per line for long lists

## Structure
- `hosts/<name>/` - Per-machine configs (darwin: chidi, jason | nixos: michael, mindy, tahani)
- `profiles/` - Reusable program/service configs (imported by hosts)
- `modules/` - Custom NixOS/darwin modules
- `lib/` - Shared constants and utilities
- `secrets/` - SOPS-encrypted secrets (`.sops.yaml` for config)
