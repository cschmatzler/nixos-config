# AGENTS.md

Personal multi-host Nix configuration built on den (vic/den) and flake-parts. See README.md for layout and commands.

## Rules

- Do not run `nix build` or `nix run .#apply` unless asked. `nix flake check` and `nix eval` are fine.
- No tests. Do not add test files or Nix checks.
- Format with `alejandra .` before committing.
- `flake.nix` is generated. Change inputs via `flake-file.inputs` in the owning module, then `nix run .#write-flake`.
- Do not bump `stateVersion`.

## Conventions

- One aspect per capability: `den.aspects.<name>.{nixos,darwin,os,homeManager}`. `os` applies to both NixOS and Darwin.
- Hosts include profiles from `modules/profiles.nix`; profiles include feature aspects. Host-only facts (hardware, networking, host services) stay in `modules/hosts/<host>.nix`.
- An aspect's `homeManager` class only applies to users that include it, so aspects with both OS and user parts appear in both a host's `includes` and its `provides.to-users.includes`.
- Non-module files (scripts, prompts, plugin sources, data) go in an underscore-prefixed sibling directory. Keep them there rather than inlining large strings.
- Secrets are declared by the feature that consumes them. Never commit plaintext.
- Prefer upstream NixOS/Home Manager/nix-darwin modules over hand-rolled scripts.
- No `specialArgs`; den provides `inputs'`. Flake-level `inputs` reach class modules by closure from the feature file.
