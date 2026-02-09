# AGENTS.md

## Build Commands

### Local Development
```bash
nix run .#build               # Build current host config
nix run .#build -- <hostname> # Build specific host (chidi, jason, michael, tahani)
nix run .#apply               # Build and apply locally (darwin-rebuild/nixos-rebuild switch)
nix flake check               # Validate flake
```

### Remote Deployment (NixOS only)
```bash
colmena build                 # Build all NixOS hosts
colmena apply --on <host>     # Deploy to specific NixOS host (michael, tahani)
colmena apply                 # Deploy to all NixOS hosts
```

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
- **Hosts**: `hosts/<hostname>/` - Per-machine configurations
  - Darwin: `chidi`, `jason`
  - NixOS: `michael`, `tahani`
- **Profiles**: `profiles/` - Reusable program/service configurations (imported by hosts)
- **Modules**: `modules/` - Custom NixOS/darwin modules
- **Lib**: `lib/` - Shared constants and utilities
- **Secrets**: `secrets/` - SOPS-encrypted secrets (`.sops.yaml` for config)

### Nix Language Conventions

**Function Arguments**:
```nix
{inputs, pkgs, lib, ...}:
```
Destructure arguments on separate lines. Use `...` to capture remaining args.

**Imports**:
```nix
../../profiles/foo.nix
```
Use relative paths from file location, not absolute paths.

**Attribute Sets**:
```nix
options.my.gitea = {
  enable = lib.mkEnableOption "Gitea git hosting service";
  bucket = lib.mkOption {
    type = lib.types.str;
    description = "S3 bucket name";
  };
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

**Modules**:
```nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.feature;
in {
  options.my.feature = {
    enable = mkEnableOption "Feature description";
  };
  config = mkIf cfg.enable {
    # configuration
  };
}
```
- Destructure args on separate lines
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
- **Option names**: `my.<feature>.<option>` for custom modules
- **Hostnames**: Lowercase, descriptive (e.g., `michael`, `tahani`)
- **Profile files**: Descriptive, lowercase with hyphens (e.g., `homebrew.nix`)

### Secrets Management
- Use SOPS for secrets (see `.sops.yaml`)
- Never commit unencrypted secrets
- Secrets files in `hosts/<host>/secrets.nix` import SOPS-generated files

### Imports Pattern
Host configs import:
1. System modules (`modulesPath + "/..."`)
2. Host-specific files (`./disk-config.nix`, `./hardware-configuration.nix`)
3. SOPS secrets (`./secrets.nix`)
4. Custom modules (`../../modules/*.nix`)
5. Base profiles (`../../profiles/*.nix`)
6. Input modules (`inputs.<module>.xxxModules.module`)

Home-manager users import profiles in a similar manner.
