# AGENTS.md

## Build Commands

### Local Development
```bash
nix run .#build               # Build current host config
nix run .#build -- <hostname> # Build specific host (chidi, janet, tahani)
nix run .#apply               # Build and apply locally (darwin-rebuild/nixos-rebuild switch)
nix flake check               # Validate flake
```

Do not run build or apply unless instructed to.

### Remote Deployment (NixOS only)
```bash
nix run .#deploy              # Deploy to all NixOS hosts
nix run .#deploy -- .#tahani  # Deploy to specific NixOS host
```

When you're on tahani and asked to apply, that means running `nix run .#deploy`.

### Formatting
```bash
alejandra .                   # Format all Nix files
```

## Code Style

### Formatter
- **Tool**: Alejandra
- **Config**: `alejandra.toml` specifies tabs for indentation
- **Command**: Run `alejandra .` before committing

### File Structure
- **Modules**: `modules/` - All configuration (flake-parts modules, auto-imported by import-tree)
  - `hosts/` - Per-host composition modules
  - `profiles/` - Shared host and user profile bundles
  - `_lib/` - Utility functions (underscore = ignored by import-tree)
  - `_darwin/` - Darwin-specific sub-modules
  - `_neovim/` - Neovim plugin configs
  - `hosts/_parts/` - Host-specific leaf files (disk-config, hardware, service fragments, etc.)
- **Apps**: `apps/` - Per-system app scripts (Nushell)
- **Secrets**: `secrets/` - SOPS-encrypted secrets (`.sops.yaml` for config)

### Architecture

**Framework**: den (vic/den) — every .nix file in `modules/` is a flake-parts module

**Pattern**: Feature/aspect-centric, not host-centric

**Aspects**: `den.aspects.<name>.<class>` where class is:
- `nixos` - NixOS-only configuration
- `darwin` - macOS-only configuration
- `homeManager` - Home Manager configuration
- `os` - Applies to both NixOS and darwin

**Hosts**: `den.hosts.<system>.<name>` declared in `modules/inventory.nix`

**Profiles**: shared bundles live under `modules/profiles/{host,user}` and are exposed as `den.aspects.host-*` and `den.aspects.user-*`

**Defaults**: `den.default.*` defined in `modules/defaults.nix`

**Imports**: Auto-imported by import-tree; underscore-prefixed dirs (`_lib/`, `_darwin/`, etc.) are excluded from auto-import

**Deployment**: deploy-rs for NixOS host `tahani`; darwin hosts (chidi, janet) are local-only

### Nix Language Conventions

**Function Arguments**:
```nix
{inputs, pkgs, lib, ...}:
```
Use `...` to capture remaining args. Let Alejandra control the exact layout.

**Attribute Sets**:
```nix
den.aspects.myfeature.os = {
  enable = true;
  config = "value";
};
```
One attribute per line with trailing semicolons.

**Lists with Packages**:
```nix
with pkgs;
[
  age
  alejandra
  ast-grep
]
```
Use `with pkgs;` for package lists, one item per line.

**Aspect Definition**:
```nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.den.aspects.myfeature;
in {
  options.den.aspects.myfeature = {
    enable = mkEnableOption "Feature description";
  };
  config = mkIf cfg.enable {
    # configuration
  };
}
```
- Use `with lib;` for brevity with NixOS lib functions
- Define `cfg` for config options
- Use `mkIf`, `mkForce`, `mkDefault` appropriately

**Conditional Platform-Specific Code**:
```nix
++ lib.optionals stdenv.isDarwin [
  _1password-gui
  dockutil
]
++ lib.optionals stdenv.isLinux [
  lm_sensors
]
```

### Naming Conventions
- **Aspect names**: `den.aspects.<name>.<class>` for feature configuration
- **Hostnames**: Lowercase, descriptive (e.g., `tahani`, `chidi`, `janet`)
- **Module files**: Descriptive, lowercase with hyphens (e.g., `neovim-config.nix`)

### Secrets Management
- Use SOPS for secrets (see `.sops.yaml`)
- Never commit unencrypted secrets
- Secret definitions live in per-host modules (`modules/hosts/tahani.nix`, etc.)
- Shared SOPS defaults (module imports, key paths) in `modules/secrets.nix`

### Aspect Composition
Use `den.aspects.<name>.includes` to compose aspects:
```nix
den.aspects.myfeature.includes = [
  "other-aspect"
  "another-aspect"
];
```

### Key Conventions
- No `specialArgs` — den batteries handle input passing
- No hostname string comparisons in shared aspects
- Host-specific config goes in `den.aspects.<hostname>.*`
- Shared config uses `os` class (applies to both NixOS and darwin)
- Non-module files go in `_`-prefixed subdirs
