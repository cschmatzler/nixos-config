# AGENTS.md

## Build Commands

### Local Development
```bash
nix run .#build                         # Build the current Host
nix run .#build -- --host <hostname>   # Build a declared Host (chidi, janet, tahani)
nix run .#apply                         # Build and apply the current Host
nix run .#rollback -- --generation <n> # Roll back the current Host
nix run .#update -- [input...]          # Update all or selected flake inputs
nix flake check                         # Validate the flake
```

Pass native build arguments after a second `--`, for example `nix run .#build -- --host tahani -- --no-link`. Apply and rollback only operate on the detected current Host and reject platform mismatches. Apply accepts only diagnostic and concurrency arguments; configuration and activation-target selectors are rejected.

Do not run build or apply unless instructed to. This repository intentionally has no tests; do not add test files or Nix test checks.

### Formatting
```bash
alejandra .                   # Format all Nix files
```

## Code Style

### Formatter
- **Tool**: Alejandra
- **Config**: default Alejandra formatting (spaces)
- **Command**: Run `alejandra .` before committing

### File Structure
- **Modules**: `modules/` - All configuration (flake-parts modules, auto-imported by import-tree)
  - `features/` - Reusable capability aspects grouped by domain (`system`, `interactive`, `development`, `ai`, `personal`, `services`)
  - `profiles/` - Include-only host and user role bundles, except identity-specific settings
  - `hosts/` - Per-host composition modules
  - `hosts/_parts/` - Host-specific leaf files (disk config, hardware, service fragments, etc.)
  - `_lib/` - Cross-feature utility functions and constants
  - `features/**/_*/` - Feature-private implementation payloads (underscore = ignored by import-tree)
- **Apps**: `apps/` - Lifecycle Command implementations with shared Host and platform validation
- **Secrets**: `secrets/` - SOPS-encrypted secrets (`.sops.yaml` for config)

### Architecture

**Framework**: den (vic/den) — every .nix file in `modules/` is a flake-parts module

**Pattern**: Feature/aspect-centric, not host-centric. Leaf aspects implement capabilities, profiles group capabilities, and hosts choose profiles.

**Aspects**: `den.aspects.<name>.<class>` where class is:
- `nixos` - NixOS-only configuration
- `darwin` - macOS-only configuration
- `homeManager` - Home Manager configuration
- `os` - Applies to both NixOS and darwin

**Hosts**: `den.hosts.<system>.<name>` declared in `modules/inventory.nix`

**Profiles**: shared bundles live under `modules/profiles/{host,user}` and are exposed as `den.aspects.host-*` and `den.aspects.user-*`

**Defaults**: `den.default.*` defined in `modules/defaults.nix`

**Inputs**: foundational inputs live in `modules/dendritic.nix`; feature-specific `flake-file.inputs` live with their owning feature or domain module

**Imports**: Auto-imported by import-tree; underscore-prefixed dirs (`_lib/`, `features/**/_*/`, etc.) are excluded from auto-import

**Lifecycle Commands**: `build` may target any declared Host; `apply` and `rollback` operate only on the detected current Host

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
- **Hostnames**: Lowercase, descriptive (e.g., `tahani`, `janet`)
- **Module files**: Descriptive, lowercase with hyphens (e.g., `neovim-config.nix`)

### Secrets Management
- Use SOPS for secrets (see `.sops.yaml`)
- Never commit unencrypted secrets
- Secret definitions live with the feature that consumes them; host aspects include the feature on the required OS/user scopes
- Shared SOPS defaults (module imports, key paths) in `modules/features/system/secrets.nix`

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
