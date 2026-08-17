# NixOS Config

Personal `den`/flake-parts configuration for three machines.

| Host | System | Role | Entry point |
| --- | --- | --- | --- |
| `chidi` | `aarch64-darwin` | Work laptop | [`modules/hosts/chidi.nix`](modules/hosts/chidi.nix) |
| `janet` | `aarch64-darwin` | Personal laptop | [`modules/hosts/janet.nix`](modules/hosts/janet.nix) |
| `tahani` | `x86_64-linux` | Home server and workstation | [`modules/hosts/tahani.nix`](modules/hosts/tahani.nix) |

## Start Here

The repository is feature/aspect-centric. Read it in this order:

1. [`modules/inventory.nix`](modules/inventory.nix) declares the hosts and their users.
2. [`modules/hosts/`](modules/hosts) composes named host and user aspects.
3. [`modules/profiles/`](modules/profiles) contains include-only role bundles composed from feature aspects.
4. [`modules/features/`](modules/features) contains reusable capability aspects grouped by domain.
5. Underscore-prefixed directories colocate implementation details that `import-tree` must not auto-import.

## Repository Map

- `modules/*.nix` — framework/bootstrap flake-parts modules
- `modules/features/{system,interactive,development,ai,personal,services}/` — reusable capability aspects grouped by domain
- `modules/features/**/_*/` — implementation payloads private to the adjacent feature domain
- `modules/hosts/` — explicit host composition
- `modules/hosts/_parts/<host>/` — machine-only hardware and literal networking leaves
- `modules/profiles/{host,user}/` — include-only role manifests, except identity-specific settings
- `modules/_lib/` — small pure helpers and personal constants
- `apps/` — Lifecycle Command implementations with shared Host and platform validation
- `secrets/` — SOPS-encrypted material only; decrypted values never enter the Nix store
- `flake.nix` — generated entrypoint; do not edit directly

## Aspect Composition

| Aspect/profile | Owns or includes |
| --- | --- |
| `host-darwin-base` | nix-darwin foundation, shared core, Tailscale |
| `host-nixos-base` | NixOS foundation, shared core, OpenSSH, Tailscale |
| `user-base` | SOPS tools, shell, SSH client |
| `user-interactive` | base user, Ghostty, CLI UX, Atuin, tmux |
| `user-developer` | Git, Nix/JavaScript/container/database tooling, mise, Neovim |
| `user-ai` | JavaScript runtime, Pi, Claude Code, Herdr |
| `user-workstation` | interactive, developer, and AI roles plus zk |
| `user-personal` | personal Git identity |

Host aspects use den's native `provides.to-users` routing. Hardware facts, state versions, and host-only services stay in the relevant host module or `_parts` leaf. A feature that spans NixOS/Darwin and Home Manager owns all of those class definitions in the same feature module.

## Where to Change Things

| Change | File |
| --- | --- |
| Host membership | [`modules/inventory.nix`](modules/inventory.nix) |
| Janet composition or lifecycle version | [`modules/hosts/janet.nix`](modules/hosts/janet.nix) |
| Tahani composition or lifecycle version | [`modules/hosts/tahani.nix`](modules/hosts/tahani.nix) |
| Tahani boot, filesystems, or swap | [`modules/hosts/_parts/tahani/hardware.nix`](modules/hosts/_parts/tahani/hardware.nix) |
| Shared Nix policy | [`modules/features/system/core.nix`](modules/features/system/core.nix) |
| macOS policy and applications | [`modules/features/system/darwin-system.nix`](modules/features/system/darwin-system.nix) |
| User profile membership | [`modules/profiles/user/`](modules/profiles/user) |
| Development capabilities | [`modules/features/development/`](modules/features/development) |
| Interactive shell and terminal capabilities | [`modules/features/interactive/`](modules/features/interactive) |
| AI capabilities, commands, and MCP endpoints | [`modules/features/ai/`](modules/features/ai) |
| SOPS integration | [`modules/features/system/secrets.nix`](modules/features/system/secrets.nix) |
| Lifecycle Command wrappers | [`modules/apps.nix`](modules/apps.nix) |

## Common Commands

```bash
nix run .#build                         # Build the current Host
nix run .#build -- --host tahani       # Build any declared Host
nix run .#build -- --host tahani -- --no-link # Forward native build arguments
nix run .#apply                         # Build and switch the current Host
nix run .#rollback -- --generation 42  # Roll back the current Host
nix run .#update -- nixpkgs            # Update selected inputs; omit names for all inputs
nix fmt                                # Format with the flake's Alejandra formatter
nix fmt -- --check .                   # Check formatting without changing files
deadnix --fail .                       # Find unused Nix bindings
statix check .                         # Run Nix static analysis
nix flake check                        # Run flake schema and generated-input checks
```

`build` may target any Host because it derives NixOS versus Darwin from the flake's configuration outputs. `apply` and `rollback` resolve the current Host, verify that its declared kind matches the invoking platform, and reject remote or cross-platform mutation. `apply` accepts only diagnostic and concurrency arguments; configuration and activation-target selectors are rejected. Lifecycle Command flags are explicit: native build arguments follow a second `--`, and rollback never prompts for a generation.

## Inputs and Generated `flake.nix`

`flake.nix` is generated by `flake-file`.

- Foundational inputs live in [`modules/dendritic.nix`](modules/dendritic.nix).
- Feature-specific inputs live beside their consumers, for example in [`modules/features/development/neovim.nix`](modules/features/development/neovim.nix), [`modules/features/ai/inputs.nix`](modules/features/ai/inputs.nix), and [`modules/features/system/secrets.nix`](modules/features/system/secrets.nix).

After changing an input declaration:

```bash
nix run .#write-flake
nix flake lock
nix fmt
```

Do not routinely bump `system.stateVersion` or `home.stateVersion`; they are compatibility contracts, not the installed package release.
