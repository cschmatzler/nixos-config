- For den migration, move legacy non-flake-parts modules into `modules/_legacy/` before enabling `inputs.import-tree ./modules`; import-tree ignores underscore-prefixed paths.
- `flake-parts` must include `inputs.nixpkgs-lib.follows = "nixpkgs"` in this repository to match den bootstrap expectations.
- The den bootstrap works with `modules/dendritic.nix` importing `(inputs.flake-file.flakeModules.dendritic or { })` and `(inputs.den.flakeModules.dendritic or { })`, plus initial `flake-file.inputs` declarations.
- Den host wiring uses `den.hosts.<system>.<hostname>.users.<username> = {}` declarations in `modules/hosts.nix` for each host-user pair.
- `den.default.includes` accepts batteries directly via `den.provides.*`; this bootstrap uses `den.provides.define-user` and `den.provides.inputs'`.
- In this flake-parts setup, declaring `options.flake.darwinConfigurations` as `lib.types.lazyAttrsOf lib.types.raw` allows multiple Darwin hosts to merge correctly.

## Task 3: Utility functions under _lib/ - COMPLETED

**What was done:**
- Created `modules/_lib/` directory
- Copied 5 pure function files (not NixOS modules):
  - `lib/constants.nix` → `modules/_lib/constants.nix` (14 lines)
  - `lib/build-rust-package.nix` → `modules/_lib/build-rust-package.nix` (20 lines)
  - `profiles/wallpaper.nix` → `modules/_lib/wallpaper.nix` (11 lines)
  - `profiles/open-project.nix` → `modules/_lib/open-project.nix` (10 lines)
  - `profiles/packages.nix` → `modules/_lib/packages.nix` (67 lines)

**Key insight:**
- import-tree ignores paths with `/_` prefix, so `modules/_lib/` is safe for pure functions
- These files are NOT NixOS/home-manager modules - they're utility functions that would crash import-tree if placed directly under `modules/`
- Files were COPIED (not moved) because old locations are still referenced by existing host configs until Task 26

**Verification:**
- All 5 files copied with identical content (byte-for-byte match)
- `alejandra --check modules/_lib/` passed (formatting compliant)
- `nix flake show` exits 0 (import-tree correctly ignores `_lib/`)

**Dependencies:**
- Unblocks Task 4 (overlays need `build-rust-package.nix` from `_lib/`)

## Task 2: Hosts and defaults bootstrap notes

- Den host wiring uses `den.hosts.<system>.<hostname>.users.<username> = {}` declarations in `modules/hosts.nix` for each host-user pair.
- `den.default.includes` accepts batteries directly via `den.provides.*`; this bootstrap uses `den.provides.define-user` and `den.provides.inputs'`.
- In this flake-parts setup, declaring `options.flake.darwinConfigurations` as `lib.types.lazyAttrsOf lib.types.raw` allows multiple Darwin hosts to merge correctly.

## Task 5: Core aspect module - COMPLETED

**What was done:**
- Created `modules/core.nix` as a flake-parts module defining `den.aspects.core`
- Ported all nix settings from `profiles/core.nix` into the `os` class (applies to both nixos and darwin)
- Updated `modules/defaults.nix` to include `den.aspects.core` in `den.default.includes`

**Key decisions:**
- Used `os` class for shared settings (fish, nushell, nixpkgs.config.allowUnfree, nix package, substituters, trusted-public-keys, gc.automatic, gc.options, experimental-features)
- Deliberately EXCLUDED `trusted-users` from core.nix (platform-specific: darwin uses "@admin", NixOS uses specific user — handled by darwin.nix and nixos-system.nix)
- Deliberately EXCLUDED gc interval/dates (platform-specific: darwin uses `interval`, NixOS uses `dates` — handled by darwin.nix and nixos-system.nix)

**Verification:**
- `modules/core.nix` created with 35 lines (exact port of profiles/core.nix settings)
- `modules/defaults.nix` updated to include `den.aspects.core` in includes list
- `alejandra .` formatted both files successfully
- `nix flake show` exits 0 (flake evaluates cleanly)

**Dependencies:**
- Unblocks Task 6 (darwin.nix and nixos-system.nix can now reference den.aspects.core)

## Task 6a: NixOS system aspect - COMPLETED

**What was done:**
- Created `modules/nixos-system.nix` as a flake-parts module defining `den.aspects.nixos-system`
- Ported NixOS-specific config from `profiles/nixos.nix` into the `nixos` class

**Key decisions:**
- Used `nixos` class (not `os`) since all settings are NixOS-specific (sudo, boot, systemd-boot, users)
- `nixos` class uses NixOS module function form `{pkgs, ...}: { ... }` to access `pkgs` for `linuxPackages_latest` and `nushell`
- `inputs` accessed from outer flake-parts module args for `home-manager.nixosModules.home-manager` import
- Hardcoded "cschmatzler" instead of variable interpolation (user is always the same)
- Hardcoded SSH keys inline instead of referencing constants (simplifies dependency)
- Deliberately EXCLUDED: system.stateVersion (in defaults.nix), sops.age.sshKeyPaths (in secrets.nix), home-manager.sharedModules/_module.args (den handles via inputs' battery)

**Pattern:**
- Outer function: `{inputs, ...}:` — flake-parts module args
- Inner class: `nixos = {pkgs, ...}: { ... }` — NixOS module function
- `imports = [inputs.home-manager.nixosModules.home-manager]` inside the nixos class

**Verification:**
- `alejandra --check .` passes (already compliant on write)
- `nix flake show` exits 0 (both michael and tahani evaluate cleanly)

## Task 6b: Darwin system aspect - COMPLETED

**What was done:**
- Created `modules/darwin.nix` as a flake-parts module defining `den.aspects.darwin-system`
- Created `modules/_darwin/dock.nix` — the dock module (NixOS-style with options/config)
- Ported profiles/darwin.nix, profiles/dock.nix, profiles/homebrew.nix, and nix-homebrew config

**Files created:**
- `modules/darwin.nix` — flake-parts module with `den.aspects.darwin-system.darwin` class
- `modules/_darwin/dock.nix` — dock options+activation script module (underscore prefix avoids import-tree)

**Key decisions:**
- `darwin` class uses NixOS module function form `{pkgs, ...}: { ... }` to access `pkgs.nushell`
- `inputs` accessed from outer flake-parts module args via closure (for nix-homebrew, home-manager, homebrew taps)
- Dock module placed in `modules/_darwin/dock.nix` and imported via `imports = [./_darwin/dock.nix]` inside the darwin class
- All `user` variable references replaced with hardcoded "cschmatzler"
- Excluded: home-manager.extraSpecialArgs (den handles via batteries), system.stateVersion (in defaults.nix)
- nix-homebrew config wired with taps from flake inputs (homebrew-core, homebrew-cask)

**Pattern for complex sub-modules:**
- Use `modules/_<platform>/` prefix (underscore avoids import-tree auto-import)
- Import from aspect class via `imports = [./_darwin/dock.nix]`
- The inner NixOS module function captures `inputs` from outer flake-parts scope via Nix closure

**Verification:**
- `alejandra .` — already compliant on write (no changes needed)
- `nix flake show` exits 0 (flake evaluates cleanly with new aspect)

## Task 23: Michael aspect with absorbed gitea module - COMPLETED

- Created `modules/_hosts/michael/` and copied `hosts/michael/disk-config.nix` plus `hosts/michael/hardware-configuration.nix` byte-for-byte into underscore-prefixed paths so import-tree ignores them.
- Added `modules/michael.nix` defining `den.aspects.michael` with includes `den.aspects.nixos-system`, `den.aspects.core`, and `den.aspects.cschmatzler`.
- Inlined the full gitea/redis/litestream/caddy/restic/systemd config directly in the michael aspect and removed dependency on `options.my.gitea`.
- Preserved intentional `lib.mkForce` overrides for litestream and restic service users/groups.
- Replaced legacy `cfg.*` references with concrete values and SOPS paths: litestream bucket `michael-gitea-litestream`, restic bucket `michael-gitea-repositories`, endpoint `s3.eu-central-003.backblazeb2.com`, and `config.sops.secrets.michael-gitea-*.path`.

## Task 25: Tahani aspect with host sub-files - COMPLETED

- Created `modules/_hosts/tahani/` and copied `hosts/tahani/{adguardhome,cache,networking,paperless}.nix` byte-for-byte into underscore-prefixed paths so import-tree ignores host-only sub-files.
- Added `modules/tahani.nix` defining `den.aspects.tahani` with includes `den.aspects.nixos-system`, `den.aspects.core`, and `den.aspects.cschmatzler` (network aspects intentionally deferred).
- Ported tahani-specific NixOS settings into the aspect (`networking.hostName`, docker enablement, docker group membership for `cschmatzler`, and 16 GiB swapfile declaration).
- Ported tahani-specific Home Manager settings into the aspect (`programs.git.settings.user.email`, zellij Nushell integration override enabled for tahani).
- Inbox-triage systemd unit now uses `pkgs.himalaya` from overlay in `PATH` (`${pkgs.himalaya}/bin`) with `inputs'.llm-agents.packages.opencode` for `ExecStart`; no `config.home-manager.users...` lookup.
- Verification: `alejandra .`, `alejandra --check .`, and `nix flake show` all pass; `lsp_diagnostics` is clean on all newly created tahani files.

- Home Manager `programs.nushell` module writes `config.nu` as a merge of: `environmentVariables` (via `load-env`), flattened `settings`, optional `configFile.text`, then `extraConfig`, then generated `shellAliases` (see HM `modules/programs/nushell.nix`). So any duplication in `config.nu` that is isolated to `extraConfig` almost always means the option value was merged multiple times (module included multiple times), not that HM writes it twice.
- In Den, HM user contexts include both the host aspect chain and the user aspect (`den.ctx.user`). If you also include the user aspect from the host aspect `includes`, user HM config is applied twice.
