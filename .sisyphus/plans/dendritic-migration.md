# Dendritic Migration: Rewrite NixOS Config with den Framework

## TL;DR

> **Quick Summary**: Complete rewrite of the NixOS/darwin configuration from host-centric architecture to feature/aspect-centric using the den framework (vic/den). Replaces specialArgs pass-through, unifies home-manager integration paths, replaces colmena with deploy-rs, and adopts auto-importing via import-tree.
> 
> **Deliverables**:
> - New `flake.nix` using den + flake-parts + import-tree + flake-file
> - All 38+ profiles converted to den aspects in `modules/`
> - All 4 hosts (chidi, jason, michael, tahani) building successfully
> - deploy-rs replacing colmena for NixOS deployment
> - Zero specialArgs usage — inputs flow via flake-parts module args
> - Overlays preserved and migrated to den module structure
> - SOPS secrets preserved exactly
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 5 waves
> **Critical Path**: Task 1 → Task 2 → Task 4 → Tasks 8-11 → Task 20 → Final

---

## Context

### Original Request
Migrate NixOS configuration to the dendritic pattern using the den framework. Organize config by feature instead of by tool (nixos vs home-manager). Make every file a flake-parts module. Eliminate specialArgs pass-through hell.

### Interview Summary
**Key Discussions**:
- **Framework choice**: User chose den (vic/den) over pure dendritic pattern — wants full aspect/context/batteries system
- **Migration strategy**: Clean rewrite, not incremental — fresh start with new structure
- **Deploy**: Replace colmena with deploy-rs for NixOS server deployment
- **Input management**: Use flake-file (vic/flake-file) to auto-manage flake.nix inputs from modules
- **Custom modules**: Absorb my.gitea and my.pgbackrest into den aspects (no separate nixosModules export)
- **Host roles**: chidi = work laptop (Slack, tuist.dev email), jason = personal laptop
- **Feature granularity**: Trusted to planner — will group by concern where natural

**Research Findings**:
- den framework provides: aspects, contexts, batteries (define-user, primary-user, user-shell, inputs')
- import-tree auto-imports all .nix files, ignores `/_` prefixed paths
- flake-file auto-manages flake.nix from module-level declarations
- deploy-rs uses `deploy.nodes.<name>` flake output — limited darwin support, use only for NixOS
- Real-world den migration examples reviewed (hyperparabolic/nix-config, dendrix community)

### Metis Review
**Identified Gaps (addressed)**:
- `local.dock.*` is a third custom module namespace that was initially missed — will be migrated
- `profiles/wallpaper.nix`, `profiles/packages.nix`, `profiles/open-project.nix` are pure functions, NOT modules — must go under `_`-prefixed paths to avoid import-tree failures
- Himalaya cross-dependency (tahani reads HM config from NixOS scope) — redesign using overlay package directly
- `zellij.nix` uses `osConfig.networking.hostName == "tahani"` hostname comparison — replace with per-host aspect override
- `pgbackrest` module is exported but never imported internally — absorb into aspects per user's decision
- `apps/` directory contains bash scripts — will be rewritten to Nushell as part of this migration
- Platform-conditional code (`stdenv.isDarwin`) in HM profiles is correct — keep, don't split into per-class
- Published flake outputs need explicit preservation decisions

---

## Work Objectives

### Core Objective
Rewrite the entire NixOS/darwin configuration to use the den framework's aspect-oriented architecture, eliminating specialArgs pass-through and organizing all configuration by feature/concern instead of by host.

### Concrete Deliverables
- New `flake.nix` with den + import-tree + flake-aspects + flake-file
- `modules/` directory with all features as den aspects (auto-imported)
- `_lib/` directory for non-module utility functions
- All 4 hosts building identically to current config
- deploy-rs configuration for michael and tahani
- No residual `hosts/`, `profiles/`, old `modules/` structure

### Definition of Done
- [ ] `nix build ".#darwinConfigurations.chidi.system"` succeeds
- [ ] `nix build ".#darwinConfigurations.jason.system"` succeeds
- [ ] `nix build ".#nixosConfigurations.michael.config.system.build.toplevel"` succeeds
- [ ] `nix build ".#nixosConfigurations.tahani.config.system.build.toplevel"` succeeds
- [ ] `nix flake check` passes
- [ ] `alejandra --check .` passes
- [ ] `nix eval ".#deploy.nodes.michael"` returns valid deploy-rs node
- [ ] `nix eval ".#deploy.nodes.tahani"` returns valid deploy-rs node
- [ ] Zero uses of `specialArgs` or `extraSpecialArgs` in codebase

### Must Have
- Exact behavioral equivalence — same services, packages, config files on all hosts
- SOPS secret paths preserved exactly (darwin: age keyfile, NixOS: ssh host key)
- Per-host git email overrides preserved (chidi→tuist.dev, jason/tahani→schmatzler.com)
- All current overlays functional
- deploy-rs for NixOS hosts (michael, tahani)
- Darwin deployment stays as local `darwin-rebuild switch` (deploy-rs has limited darwin support)
- All stateVersion values unchanged (darwin: 6, nixos: "25.11", homeManager: "25.11")
- All perSystem apps (build, apply, build-switch, rollback) preserved or equivalently replaced

### Must NOT Have (Guardrails)
- MUST NOT add new packages, services, or features not in current config
- MUST NOT split simple single-concern profiles into multiple aspects (atuin.nix → one aspect)
- MUST NOT add abstractions for "future use" (multi-user support, dynamic host detection, etc.)
- MUST NOT rewrite app scripts in any language other than Nushell (per AGENTS.md scripting policy)
- MUST NOT change any stateVersion values
- MUST NOT re-encrypt or restructure SOPS secrets — paths and key assignments stay identical
- MUST NOT change any service configuration values (ports, paths, domains, credentials)
- MUST NOT add den batteries beyond what's needed — each must map to a current requirement
- MUST NOT create abstractions over overlays (current pattern is clear)
- MUST NOT add excessive comments, JSDoc, or documentation to nix files
- MUST NOT use hostname string comparisons in shared aspects (no `osConfig.networking.hostName == "tahani"`)
- MUST NOT read HM config values from NixOS scope (the himalaya anti-pattern)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (this is a NixOS config, not a software project)
- **Automated tests**: None (verification is via `nix build` / `nix eval` / `nix flake check`)
- **Framework**: N/A

### QA Policy
Every task MUST verify its changes compile via `nix eval` or `nix build --dry-run`.
Formatting MUST pass `alejandra --check .` after every file change.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — flake bootstrap + utilities):
├── Task 1: New flake.nix with den + import-tree + flake-file [deep]
├── Task 2: den bootstrap module (hosts, users, defaults, base) [deep]
├── Task 3: Utility functions under _lib/ [quick]
├── Task 4: Overlays module [quick]
├── Task 5: SOPS secrets aspects (all 4 hosts) [quick]
└── Task 6: Deploy-rs module [quick]

Wave 2 (Core shared aspects — no host dependencies):
├── Task 7: Core system aspect (nix settings, shells) [quick]
├── Task 8: Darwin system aspect (system defaults, dock, homebrew, nix-homebrew) [unspecified-high]
├── Task 9: NixOS system aspect (boot, sudo, systemd, users) [unspecified-high]
├── Task 10: User aspect (cschmatzler — define-user, primary-user, shell) [quick]
└── Task 11: perSystem apps module [quick]

Wave 3 (Home-manager aspects — bulk migration, MAX PARALLEL):
├── Task 12: Shell aspects (nushell, bash, zsh, starship) [quick]
├── Task 13: Dev tools aspects (git, jujutsu, lazygit, jjui, direnv, mise) [quick]
├── Task 14: Editor aspects (neovim/nixvim) [unspecified-high]
├── Task 15: Terminal aspects (ghostty, zellij, yazi, bat, fzf, ripgrep, zoxide) [quick]
├── Task 16: Communication aspects (himalaya, mbsync, ssh) [unspecified-high]
├── Task 17: Desktop aspects (aerospace, wallpaper, home base) [quick]
├── Task 18: AI tools aspects (opencode, claude-code) [quick]
└── Task 19: Miscellaneous aspects (atuin, zk, open-project) [quick]

Wave 4 (Host-specific + services + scripts):
├── Task 20: Server aspects — michael (gitea + litestream + restic) [deep]
├── Task 21: Server aspects — tahani (adguard, paperless, docker, inbox-triage) [deep]
├── Task 22: Host aspects — chidi (work-specific) [quick]
├── Task 23: Host aspects — jason (personal-specific) [quick]
├── Task 24: Network aspects (openssh, fail2ban, tailscale, postgresql) [quick]
├── Task 25: Packages aspect (system packages list) [quick]
└── Task 29: Rewrite apps/ scripts from bash to Nushell [quick]

Wave 5 (Cleanup + verification):
├── Task 26: Remove old structure (hosts/, profiles/, old modules/) [quick]
├── Task 27: Full build verification all 4 hosts [deep]
└── Task 28: Formatting pass + final cleanup [quick]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 2 → Task 7 → Tasks 8-9 → Task 10 → Tasks 12-19 → Tasks 20-21 + Task 29 → Task 27 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 8 (Wave 3)
```

### Dependency Matrix

- **1**: — — 2, 3, 4, 5, 6, 11, W1
- **2**: 1 — 7, 8, 9, 10, W1
- **3**: 1 — 4, 14, 16, 20, 21, W1
- **4**: 1, 3 — 7, 8, 9, W1
- **5**: 1, 2 — 20, 21, 22, 23, W1
- **6**: 1, 2 — 27, W1
- **7**: 2, 4 — 12-19, W2
- **8**: 2, 4 — 17, 22, 23, W2
- **9**: 2, 4 — 20, 21, 24, W2
- **10**: 2 — 12-19, W2
- **11**: 1 — 27, W2
- **12-19**: 7, 10 — 20-25, W3
- **20**: 5, 9, 14, 16 — 27, W4
- **21**: 5, 9, 16, 18 — 27, W4
- **22**: 5, 8, 17 — 27, W4
- **23**: 5, 8, 17 — 27, W4
- **24**: 9 — 27, W4
- **25**: 7 — 27, W4
- **29**: 11 — 27, W4
- **26**: 27 — F1-F4, W5
- **27**: 20-25, 29 — 26, 28, W5
- **28**: 27 — F1-F4, W5

### Agent Dispatch Summary

- **W1**: **6** — T1 → `deep`, T2 → `deep`, T3 → `quick`, T4 → `quick`, T5 → `quick`, T6 → `quick`
- **W2**: **5** — T7 → `quick`, T8 → `unspecified-high`, T9 → `unspecified-high`, T10 → `quick`, T11 → `quick`
- **W3**: **8** — T12-T13 → `quick`, T14 → `unspecified-high`, T15 → `quick`, T16 → `unspecified-high`, T17-T19 → `quick`
- **W4**: **7** — T20-T21 → `deep`, T22-T25 → `quick`, T29 → `quick`
- **W5**: **3** — T26 → `quick`, T27 → `deep`, T28 → `quick`
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. New flake.nix with den + import-tree + flake-file

  **What to do**:
  - Move existing `modules/gitea.nix` and `modules/pgbackrest.nix` to `modules/_legacy/` (underscore prefix = ignored by import-tree). These will be absorbed into den aspects in Tasks 20/21 and deleted in Task 26
  - Create new `flake.nix` that uses `flake-parts.lib.mkFlake` with `inputs.import-tree ./modules`
  - Add all required inputs: preserve existing (nixpkgs, flake-parts, sops-nix, home-manager, darwin, nix-homebrew, homebrew-core, homebrew-cask, nixvim, zjstatus, llm-agents, disko, jj-ryu, jj-starship, himalaya, naersk, tuicr) AND add new required inputs (den, import-tree, flake-aspects, flake-file, deploy-rs)
  - Preserve all existing `follows` declarations and `flake = false` attributes
  - The `outputs` should be minimal: `inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)`
  - Remove the old `outputs` block entirely (specialArgs, genAttrs, inline configs — all gone)
  - Create a minimal placeholder module in `modules/` (e.g. empty flake-parts module) so import-tree has something to import
  - Ensure `nix flake show` doesn't error

  **Must NOT do**:
  - Do not include ANY configuration logic in flake.nix — everything goes in modules/
  - Do not change any existing input URLs or versions
  - Do not add inputs beyond the required new ones (den, import-tree, flake-aspects, flake-file, deploy-rs)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: This is the highest-risk task — if the flake bootstrap is wrong, nothing works. Needs careful attention to input declarations, follows chains, and flake-file compatibility.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (start first)
  - **Blocks**: All other tasks
  - **Blocked By**: None

  **References**:
  - `flake.nix:1-168` — Current flake with all inputs and follows declarations to preserve
  - `templates/default/flake.nix` in vic/den repo — Reference flake.nix structure using import-tree
  - den migration guide: https://den.oeiuwq.com/guides/migrate/
  - import-tree README: https://github.com/vic/import-tree — Auto-import pattern
  - flake-file: https://github.com/vic/flake-file — For auto-managing inputs from modules

  **Acceptance Criteria**:
  - [ ] `flake.nix` has all current inputs preserved with correct follows
  - [ ] `flake.nix` has new required inputs: den, import-tree, flake-aspects, flake-file, deploy-rs
  - [ ] `flake.nix` outputs use `import-tree ./modules`
  - [ ] `modules/_legacy/gitea.nix` and `modules/_legacy/pgbackrest.nix` exist (moved from modules/)
  - [ ] `nix flake show` doesn't error (with a minimal placeholder module)

  **QA Scenarios**:
  ```
  Scenario: Flake evaluates without errors
    Tool: Bash
    Preconditions: New flake.nix written, modules/ directory exists with at least one .nix file
    Steps:
      1. Run `nix flake show --json 2>&1`
      2. Assert exit code 0
      3. Run `nix flake check --no-build 2>&1`
    Expected Result: Both commands exit 0 without evaluation errors
    Evidence: .sisyphus/evidence/task-1-flake-eval.txt

  Scenario: All inputs preserved
    Tool: Bash
    Preconditions: New flake.nix written
    Steps:
      1. Run `nix flake metadata --json | nu -c '$in | from json | get locks.nodes | columns | sort'`
      2. Compare against expected list: [darwin, disko, deploy-rs, den, flake-aspects, flake-file, flake-parts, himalaya, home-manager, homebrew-cask, homebrew-core, import-tree, jj-ryu, jj-starship, llm-agents, naersk, nix-homebrew, nixpkgs, nixvim, sops-nix, tuicr, zjstatus]
    Expected Result: All inputs present in lock file
    Evidence: .sisyphus/evidence/task-1-inputs.txt
  ```

  **Commit**: YES (group with 2, 3)
  - Message: `feat(den): bootstrap flake with den + import-tree + flake-file`
  - Files: `flake.nix`, `modules/`
  - Pre-commit: `alejandra --check .`

- [x] 2. Den bootstrap module — hosts, users, defaults, base

  **What to do**:
  - Create `modules/den.nix` — import den flakeModule, declare all 4 hosts and their users:
    ```nix
    den.hosts.aarch64-darwin.chidi.users.cschmatzler = {};
    den.hosts.aarch64-darwin.jason.users.cschmatzler = {};
    den.hosts.x86_64-linux.michael.users.cschmatzler = {};
    den.hosts.x86_64-linux.tahani.users.cschmatzler = {};
    ```
  - Set `den.base.user.classes = lib.mkDefault ["homeManager"];`
  - Create `modules/defaults.nix` — define `den.default` with:
    - `includes = [den.provides.define-user den.provides.inputs']`
    - State versions: `nixos.system.stateVersion = "25.11"`, `homeManager.home.stateVersion = "25.11"`
    - Darwin state version handled per-class
  - Wire flake-file module import if needed
  - Create `modules/flake-parts.nix` to import `inputs.flake-parts.flakeModules.modules`

  **Must NOT do**:
  - Do not add multi-user abstractions
  - Do not add batteries not needed
  - Do not change stateVersion values

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core den bootstrap — needs understanding of den's host/user/aspect model and correct battery usage
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (after Task 1)
  - **Blocks**: Tasks 7-10, all Wave 2+
  - **Blocked By**: Task 1

  **References**:
  - `lib/constants.nix:1-14` — Current constants (user name, SSH keys, stateVersions)
  - den docs: https://den.oeiuwq.com/guides/declare-hosts/ — Host/user declaration
  - den docs: https://den.oeiuwq.com/guides/batteries/ — Available batteries
  - `templates/example/modules/den.nix` in vic/den — Example host declarations
  - `templates/minimal/modules/den.nix` in vic/den — Minimal den setup with aspects

  **Acceptance Criteria**:
  - [ ] `nix eval ".#darwinConfigurations" --json` shows chidi and jason
  - [ ] `nix eval ".#nixosConfigurations" --json` shows michael and tahani
  - [ ] den.default includes define-user and inputs' batteries

  **QA Scenarios**:
  ```
  Scenario: All 4 host configurations exist
    Tool: Bash
    Preconditions: modules/den.nix and modules/defaults.nix created
    Steps:
      1. Run `nix eval ".#darwinConfigurations" --json 2>&1 | nu -c '$in | from json | columns | sort'`
      2. Assert output contains "chidi" and "jason"
      3. Run `nix eval ".#nixosConfigurations" --json 2>&1 | nu -c '$in | from json | columns | sort'`
      4. Assert output contains "michael" and "tahani"
    Expected Result: All 4 hosts registered
    Evidence: .sisyphus/evidence/task-2-hosts.txt
  ```

  **Commit**: YES (group with 1, 3)
  - Message: `feat(den): bootstrap flake with den + import-tree + flake-file`
  - Files: `modules/den.nix`, `modules/defaults.nix`, `modules/flake-parts.nix`
  - Pre-commit: `alejandra --check .`

- [x] 3. Utility functions under _lib/

  **What to do**:
  - Create `modules/_lib/` directory (underscore prefix = ignored by import-tree)
  - Move `lib/build-rust-package.nix` → `modules/_lib/build-rust-package.nix` (preserve content exactly)
  - Convert `profiles/wallpaper.nix` → `modules/_lib/wallpaper.nix` (it's a pure function `{pkgs}: ...`, not a module)
  - Convert `profiles/open-project.nix` → `modules/_lib/open-project.nix` (pure function)
  - Move `lib/constants.nix` → `modules/_lib/constants.nix` (preserve content exactly — values used by den.base and aspects)
  - NOTE: `profiles/packages.nix` is also a function (`callPackage`-compatible) — convert to `modules/_lib/packages.nix`

  **Must NOT do**:
  - Do not modify function signatures or return values
  - Do not place these under non-underscore paths (import-tree would fail)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file moves/copies with path updates
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 4, 5, 6)
  - **Blocks**: Tasks that reference these utilities (overlays, packages, wallpaper aspects)
  - **Blocked By**: Task 1

  **References**:
  - `lib/constants.nix:1-14` — Constants to move
  - `lib/build-rust-package.nix` — Rust package builder overlay helper
  - `profiles/wallpaper.nix` — Pure function returning derivation
  - `profiles/open-project.nix` — Pure function returning derivation
  - `profiles/packages.nix` — callPackage-compatible function returning package list
  - import-tree docs: `/_` prefix convention for ignoring paths

  **Acceptance Criteria**:
  - [ ] `modules/_lib/` directory exists with all 5 files
  - [ ] No function files exist under non-underscore paths in modules/
  - [ ] `alejandra --check modules/_lib/` passes

  **QA Scenarios**:
  ```
  Scenario: Utility files exist and are ignored by import-tree
    Tool: Bash
    Preconditions: _lib/ directory created with all files
    Steps:
      1. Verify `modules/_lib/constants.nix` exists
      2. Verify `modules/_lib/build-rust-package.nix` exists
      3. Verify `modules/_lib/wallpaper.nix` exists
      4. Verify `modules/_lib/open-project.nix` exists
      5. Verify `modules/_lib/packages.nix` exists
      6. Run `nix flake check --no-build` to confirm import-tree ignores _lib/
    Expected Result: All files present, flake evaluates without trying to import them as modules
    Evidence: .sisyphus/evidence/task-3-lib-files.txt
  ```

  **Commit**: YES (group with 1, 2)
  - Message: `feat(den): bootstrap flake with den + import-tree + flake-file`
  - Files: `modules/_lib/*`

- [x] 4. Overlays module

  **What to do**:
  - Create `modules/overlays.nix` — a flake-parts module that defines all overlays
  - Port the current overlay pattern: each overlay takes `inputs` from flake-parts module args and produces a nixpkgs overlay
  - Register overlays via `nixpkgs.overlays` in `den.default` or via `flake.overlays`
  - Port these overlays: himalaya, jj-ryu (uses _lib/build-rust-package.nix), jj-starship (passthrough), tuicr, zjstatus
  - The current dynamic loader pattern (`overlays/default.nix`) is no longer needed — each overlay is defined inline or imported from `_lib/`
  - Ensure overlays are applied to all hosts via `den.default.nixos` and `den.default.darwin` or equivalent

  **Must NOT do**:
  - Do not create abstractions over the overlay pattern
  - Do not change what packages the overlays produce
  - Do not publish `flake.overlays` output (user chose to absorb into aspects — if external consumers need it, reconsider)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Translating existing overlays into a flake-parts module is straightforward
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 3, 5, 6)
  - **Blocks**: Tasks 7-9 (overlays must be registered before host configs use overlayed packages)
  - **Blocked By**: Tasks 1, 3

  **References**:
  - `overlays/default.nix:1-18` — Current dynamic overlay loader
  - `overlays/himalaya.nix:1-3` — Overlay pattern: `{inputs}: final: prev: { himalaya = inputs.himalaya.packages...; }`
  - `overlays/jj-ryu.nix` — Uses `_lib/build-rust-package.nix` helper with naersk
  - `overlays/jj-starship.nix` — Passes through upstream overlay
  - `overlays/zjstatus.nix` — Package from input
  - `overlays/tuicr.nix` — Package from input

  **Acceptance Criteria**:
  - [ ] `modules/overlays.nix` defines all 5 overlays
  - [ ] Overlays are applied to nixpkgs for all hosts
  - [ ] `nix eval ".#nixosConfigurations.tahani.config.nixpkgs.overlays" --json` shows overlays present

  **QA Scenarios**:
  ```
  Scenario: Overlayed packages are available
    Tool: Bash
    Preconditions: overlays.nix created and hosts building
    Steps:
      1. Run `nix eval ".#nixosConfigurations.tahani.pkgs.himalaya" --json 2>&1`
      2. Assert it evaluates (doesn't error with "himalaya not found")
    Expected Result: himalaya package resolves from overlay
    Evidence: .sisyphus/evidence/task-4-overlays.txt
  ```

  **Commit**: NO (groups with Wave 1)

- [x] 5. SOPS secrets aspects (all 4 hosts)

  **What to do**:
  - Create `modules/secrets.nix` — a flake-parts module handling SOPS for all hosts
  - Use den aspects to define per-host secrets:
    - `den.aspects.chidi`: darwin SOPS — `sops.age.keyFile = "/Users/cschmatzler/.config/sops/age/keys.txt"`, disable ssh/gnupg paths
    - `den.aspects.jason`: same darwin SOPS pattern
    - `den.aspects.michael`: NixOS SOPS — `sops.age.sshKeyPaths`, define secrets (michael-gitea-litestream, michael-gitea-restic-password, michael-gitea-restic-env) with exact same sopsFile paths, owners, groups
    - `den.aspects.tahani`: NixOS SOPS — define secrets (tahani-paperless-password, tahani-email-password) with exact same paths and owners
  - Import sops-nix modules per-class: `den.default.nixos` imports `inputs.sops-nix.nixosModules.sops`, `den.default.darwin` imports `inputs.sops-nix.darwinModules.sops`
  - Use flake-file to declare sops-nix input dependency from this module

  **Must NOT do**:
  - Do not change any sopsFile paths, owners, groups, or formats
  - Do not re-encrypt secrets
  - Do not modify the `secrets/` directory structure

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Direct translation of existing secrets config into den aspects
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 3, 4, 6)
  - **Blocks**: Tasks 20-23 (host aspects need secrets available)
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `hosts/chidi/secrets.nix:1-5` — Darwin SOPS pattern
  - `hosts/jason/secrets.nix` — Same as chidi
  - `hosts/michael/secrets.nix:1-22` — NixOS SOPS with gitea secrets (owners, groups, sopsFile paths)
  - `hosts/tahani/secrets.nix:1-13` — NixOS SOPS with paperless + email secrets
  - `profiles/nixos.nix:57` — `sops.age.sshKeyPaths` for NixOS
  - `secrets/` directory — Encrypted secret files (DO NOT MODIFY)

  **Acceptance Criteria**:
  - [ ] `nix eval ".#nixosConfigurations.michael.config.sops.secrets" --json | nu -c '$in | from json | columns'` contains michael-gitea-litestream, michael-gitea-restic-password, michael-gitea-restic-env
  - [ ] `nix eval ".#nixosConfigurations.tahani.config.sops.secrets" --json | nu -c '$in | from json | columns'` contains tahani-paperless-password, tahani-email-password

  **QA Scenarios**:
  ```
  Scenario: SOPS secrets paths preserved exactly
    Tool: Bash
    Preconditions: secrets.nix module created
    Steps:
      1. Run `nix eval ".#nixosConfigurations.michael.config.sops.secrets" --json 2>&1`
      2. Assert keys include michael-gitea-litestream, michael-gitea-restic-password, michael-gitea-restic-env
      3. Run `nix eval ".#nixosConfigurations.tahani.config.sops.secrets" --json 2>&1`
      4. Assert keys include tahani-paperless-password, tahani-email-password
    Expected Result: All secrets defined with correct paths
    Evidence: .sisyphus/evidence/task-5-sops.txt

  Scenario: Darwin SOPS uses age keyfile, not SSH
    Tool: Bash
    Preconditions: secrets.nix module created
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.sops.age.keyFile" 2>&1`
      2. Assert output is "/Users/cschmatzler/.config/sops/age/keys.txt"
    Expected Result: Darwin hosts use age keyfile path
    Evidence: .sisyphus/evidence/task-5-sops-darwin.txt
  ```

  **Commit**: NO (groups with Wave 1)

- [x] 6. Deploy-rs module

  **What to do**:
  - Create `modules/deploy.nix` — a flake-parts module that configures deploy-rs
  - Add `deploy-rs` as a flake input (replacing colmena)
  - Define `flake.deploy.nodes.michael` and `flake.deploy.nodes.tahani` with:
    - `hostname = "<hostname>"`
    - `profiles.system.user = "root"`
    - `profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.<hostname>`
    - `sshUser = "cschmatzler"`
  - Add deploy-rs checks to `flake.checks` via `deploy-rs.lib.x86_64-linux.deployChecks self.deploy`
  - Only NixOS hosts — darwin stays local `darwin-rebuild switch`
  - Use flake-file to declare deploy-rs input from this module

  **Must NOT do**:
  - Do not add darwin deploy-rs nodes (limited support)
  - Do not remove the perSystem apps that handle darwin apply

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward deploy-rs configuration with two nodes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 3, 4, 5)
  - **Blocks**: Task 27 (verification needs deploy-rs nodes)
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `flake.nix:110-130` — Current colmena config to replace
  - deploy-rs docs: https://github.com/serokell/deploy-rs — Node config format
  - Current deployment users: `user = "cschmatzler"` for colmena targetUser

  **Acceptance Criteria**:
  - [ ] `nix eval ".#deploy.nodes.michael.hostname"` returns "michael"
  - [ ] `nix eval ".#deploy.nodes.tahani.hostname"` returns "tahani"
  - [ ] deploy-rs checks registered in flake checks

  **QA Scenarios**:
  ```
  Scenario: deploy-rs nodes exist for NixOS hosts only
    Tool: Bash
    Preconditions: deploy.nix module created
    Steps:
      1. Run `nix eval ".#deploy.nodes" --json 2>&1 | nu -c '$in | from json | columns | sort'`
      2. Assert output is ["michael", "tahani"]
      3. Assert no darwin hosts in deploy nodes
    Expected Result: Exactly 2 deploy nodes for NixOS hosts
    Evidence: .sisyphus/evidence/task-6-deploy.txt
  ```

  **Commit**: NO (groups with Wave 1)

- [x] 7. Core system aspect (nix settings, shells)

  **What to do**:
  - Create `modules/core.nix` — den aspect for core nix/system settings shared across all hosts
  - Port `profiles/core.nix` content into `den.aspects.core` with appropriate per-class configs:
    - `os` class (or both `nixos` and `darwin`): nix settings (experimental-features, auto-optimise-store), fish shell enable, environment.systemPackages (common tools)
  - Include this aspect in `den.default.includes` so all hosts get it
  - Remove the `user` and `constants` args dependency — use den context instead

  **Must NOT do**:
  - Do not change nix settings values
  - Do not add packages not in current core.nix

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8-11)
  - **Blocks**: Tasks 12-19 (Wave 3 aspects may depend on core being applied)
  - **Blocked By**: Tasks 2, 4

  **References**:
  - `profiles/core.nix` — Current core profile with nix settings, fish, systemPackages

  **Acceptance Criteria**:
  - [ ] `den.default.includes` contains core aspect
  - [ ] nix experimental-features setting preserved

  **QA Scenarios**:
  ```
  Scenario: Core nix settings applied to all hosts
    Tool: Bash
    Steps:
      1. Run `nix eval ".#nixosConfigurations.michael.config.nix.settings.experimental-features" --json 2>&1`
      2. Assert contains "nix-command" and "flakes"
    Expected Result: Nix settings from core.nix applied
    Evidence: .sisyphus/evidence/task-7-core.txt
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 8. Darwin system aspect (system defaults, dock, homebrew, nix-homebrew)

  **What to do**:
  - Create `modules/darwin.nix` — den aspect for darwin-specific system configuration
  - Port `profiles/darwin.nix` into `den.aspects.darwin-system`:
    - `darwin` class: system.defaults (NSGlobalDomain, dock, finder, trackpad, screencapture, screensaver, loginwindow, spaces, WindowManager, menuExtraClock, CustomUserPreferences), nix GC settings, nix trusted-users
    - User creation for darwin (users.users.${user}) — or rely on den.provides.define-user
    - `home-manager.useGlobalPkgs = true`
  - Port `profiles/dock.nix` — the `local.dock.*` custom option module. Absorb into the darwin aspect or create `modules/dock.nix`
  - Port `profiles/homebrew.nix` into `modules/homebrew.nix` — nix-homebrew configuration with taps, casks, etc.
  - Include darwin-system aspect in darwin host aspects (chidi, jason)
  - Wire nix-homebrew module import via `den.aspects.darwin-system.darwin`
  - State version: `system.stateVersion = 6` (from constants.stateVersions.darwin)

  **Must NOT do**:
  - Do not change any system.defaults values
  - Do not change dock entries
  - Do not change homebrew taps or cask lists

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple complex darwin profiles need merging into aspects with correct module imports
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 9-11)
  - **Blocks**: Tasks 17, 22, 23 (desktop and host-specific darwin)
  - **Blocked By**: Tasks 2, 4

  **References**:
  - `profiles/darwin.nix:1-125` — Full darwin system config (system defaults, users, nix settings)
  - `profiles/dock.nix` — Custom `local.dock.*` option module with entries
  - `profiles/homebrew.nix` — Homebrew config with taps, brews, casks
  - `flake.nix:77-94` — Current darwin configuration wiring (nix-homebrew module, homebrew taps)

  **Acceptance Criteria**:
  - [ ] All system.defaults values preserved
  - [ ] nix-homebrew configured with same taps
  - [ ] dock entries preserved
  - [ ] `nix eval ".#darwinConfigurations.chidi.config.system.defaults.NSGlobalDomain.AppleInterfaceStyle"` returns null

  **QA Scenarios**:
  ```
  Scenario: Darwin system defaults applied
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.system.defaults.dock.autohide" 2>&1`
      2. Assert output is "true"
    Expected Result: Dock autohide preserved from darwin.nix
    Evidence: .sisyphus/evidence/task-8-darwin.txt
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 9. NixOS system aspect (boot, sudo, systemd, users)

  **What to do**:
  - Create `modules/nixos-system.nix` — den aspect for NixOS-specific system configuration
  - Port `profiles/nixos.nix` into `den.aspects.nixos-system`:
    - `nixos` class: security.sudo, boot (systemd-boot, EFI, kernel modules, latest kernel), nix settings (trusted-users, gc, nixPath), time.timeZone, user creation with groups
    - `home-manager.useGlobalPkgs = true` and `home-manager.sharedModules` — but this should now be handled by den's HM integration battery (no manual _module.args)
    - Root user SSH authorized keys from constants
  - State version: `system.stateVersion = "25.11"`
  - `sops.age.sshKeyPaths` for NixOS hosts

  **Must NOT do**:
  - Do not change sudo rules
  - Do not change boot loader settings
  - Do not change user groups

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: NixOS system profile has multiple interconnected settings that need careful migration
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 8, 10, 11)
  - **Blocks**: Tasks 20, 21, 24 (server and network aspects)
  - **Blocked By**: Tasks 2, 4

  **References**:
  - `profiles/nixos.nix:1-79` — Full NixOS system config (sudo, boot, nix, users, HM wiring)
  - `lib/constants.nix:4-7` — SSH keys for root and user

  **Acceptance Criteria**:
  - [ ] sudo rules preserved exactly
  - [ ] boot settings (systemd-boot, kernel) preserved
  - [ ] No manual `_module.args` or `sharedModules` for HM — den handles it
  - [ ] Root SSH authorized keys set

  **QA Scenarios**:
  ```
  Scenario: NixOS boot config preserved
    Tool: Bash
    Steps:
      1. Run `nix eval ".#nixosConfigurations.michael.config.boot.loader.systemd-boot.enable" 2>&1`
      2. Assert output is "true"
    Expected Result: Boot settings from nixos.nix preserved
    Evidence: .sisyphus/evidence/task-9-nixos.txt
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 10. User aspect (cschmatzler — primary user)

  **What to do**:
  - Create `modules/user.nix` — den aspect for the cschmatzler user
  - Define `den.aspects.cschmatzler`:
    - `includes`: `den.provides.primary-user`, `(den.provides.user-shell "nushell")`, relevant shared aspects
    - `homeManager`: basic home config from `profiles/home.nix` (programs.home-manager.enable, home.packages via callPackage _lib/packages.nix, home.activation for wallpaper on darwin)
    - SSH authorized keys from constants
  - The user aspect is the central hub that `includes` all feature aspects the user wants
  - Per-host email overrides will be in host aspects (Tasks 22-23), not here
  - Default email: `homeManager.programs.git.settings.user.email` left for host-specific override

  **Must NOT do**:
  - Do not add features not in current user config
  - Do not set git email here (it's per-host)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7-9, 11)
  - **Blocks**: Tasks 12-19 (HM aspects)
  - **Blocked By**: Task 2

  **References**:
  - `profiles/home.nix:1-24` — Home base config (home-manager enable, packages, wallpaper activation)
  - `lib/constants.nix:2` — User name "cschmatzler"
  - `lib/constants.nix:4-7` — SSH authorized keys
  - den batteries docs: https://den.oeiuwq.com/guides/batteries/ — primary-user, user-shell

  **Acceptance Criteria**:
  - [ ] `den.aspects.cschmatzler` defined with primary-user and user-shell batteries
  - [ ] Home packages list from packages.nix applied

  **QA Scenarios**:
  ```
  Scenario: User aspect creates correct system user
    Tool: Bash
    Steps:
      1. Run `nix eval ".#nixosConfigurations.michael.config.users.users.cschmatzler.isNormalUser" 2>&1`
      2. Assert output is "true"
    Expected Result: User created with isNormalUser
    Evidence: .sisyphus/evidence/task-10-user.txt
  ```

  **Commit**: NO (groups with Wave 2)

- [x] 11. perSystem apps module

  **What to do**:
  - Create `modules/apps.nix` — a flake-parts module that defines perSystem apps
  - Port the current `perSystem` block from flake.nix that creates apps: build, apply, build-switch, rollback
  - These apps reference `apps/${system}/${name}` shell scripts — keep this mechanism
  - Ensure apps are available for both x86_64-linux and aarch64-darwin

  **Must NOT do**:
  - Do not change app behavior (the actual script rewrite to Nushell is Task 29)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7-10)
  - **Blocks**: Task 27 (verification)
  - **Blocked By**: Task 1

  **References**:
  - `flake.nix:143-165` — Current perSystem apps block
  - `apps/` directory — Shell scripts for each platform

  **Acceptance Criteria**:
  - [ ] `nix eval ".#apps.aarch64-darwin" --json | nu -c '$in | from json | columns'` includes build, apply
  - [ ] `nix eval ".#apps.x86_64-linux" --json | nu -c '$in | from json | columns'` includes build, apply

  **QA Scenarios**:
  ```
  Scenario: perSystem apps accessible
    Tool: Bash
    Steps:
      1. Run `nix eval ".#apps.aarch64-darwin" --json 2>&1 | nu -c '$in | from json | columns | sort'`
      2. Assert contains apply, build, build-switch, rollback
    Expected Result: All 4 apps registered
    Evidence: .sisyphus/evidence/task-11-apps.txt
  ```

  **Commit**: NO (groups with Wave 2)

- [ ] 12. Shell aspects (nushell, bash, zsh, starship)

  **What to do**:
  - Create `modules/shell.nix` — den aspect grouping shell-related HM config
  - Port into `den.aspects.shell.homeManager`: nushell config (`profiles/nushell.nix` — programs.nushell with aliases, env, config, platform-conditional PATH), bash config (`profiles/bash.nix`), zsh config (`profiles/zsh.nix`), starship config (`profiles/starship.nix` — programs.starship with settings)
  - Keep `stdenv.isDarwin` platform checks in HM config — these are correct in HM context
  - Include shell aspect in user aspect (Task 10's `den.aspects.cschmatzler.includes`)

  **Must NOT do**:
  - Do not change shell aliases, env vars, or config values
  - Do not split into 4 separate aspects (these are naturally grouped)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 13-19)
  - **Blocks**: Tasks 20-25
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/nushell.nix` — Nushell config with platform conditionals
  - `profiles/bash.nix` — Bash config
  - `profiles/zsh.nix` — Zsh config
  - `profiles/starship.nix` — Starship prompt config

  **Acceptance Criteria**:
  - [ ] All shell programs configured in HM
  - [ ] Platform-conditional nushell PATH preserved

  **QA Scenarios**:
  ```
  Scenario: Shell programs enabled in HM
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.nushell.enable" 2>&1`
      2. Assert true
    Expected Result: Nushell enabled
    Evidence: .sisyphus/evidence/task-12-shell.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 13. Dev tools aspects (git, jujutsu, lazygit, jjui, direnv, mise)

  **What to do**:
  - Create `modules/dev-tools.nix` — den aspect grouping developer tools HM config
  - Port into `den.aspects.dev-tools.homeManager`: git config (`profiles/git.nix` — programs.git with aliases, settings, ignores, diff tools), jujutsu config (`profiles/jujutsu.nix`), lazygit (`profiles/lazygit.nix`), jjui (`profiles/jjui.nix`), direnv (`profiles/direnv.nix`), mise (`profiles/mise.nix`)
  - NOTE: Do NOT set `programs.git.settings.user.email` here — that's per-host
  - Include dev-tools aspect in user aspect

  **Must NOT do**:
  - Do not change git aliases or settings
  - Do not set git email (per-host override)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12, 14-19)
  - **Blocks**: Tasks 20-25
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/git.nix` — Git config with delta, aliases, ignores
  - `profiles/jujutsu.nix` — Jujutsu VCS config
  - `profiles/lazygit.nix` — Lazygit TUI
  - `profiles/jjui.nix` — jj TUI
  - `profiles/direnv.nix` — Direnv with nix-direnv
  - `profiles/mise.nix` — Mise version manager

  **Acceptance Criteria**:
  - [ ] All dev tools configured
  - [ ] Git email NOT set in this aspect

  **QA Scenarios**:
  ```
  Scenario: Git configured without email override
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.git.enable" 2>&1`
      2. Assert true
    Expected Result: Git enabled in HM
    Evidence: .sisyphus/evidence/task-13-devtools.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 14. Editor aspects (neovim/nixvim)

  **What to do**:
  - Create `modules/neovim/` directory with den aspect for neovim/nixvim
  - Port the entire `profiles/neovim/` directory (16+ files) into den aspect structure
  - The main module (`profiles/neovim/default.nix`) imports all plugin configs — replicate this structure
  - Import `inputs.nixvim.homeModules.nixvim` in the HM class config
  - Use flake-file to declare nixvim input dependency from this module
  - The neovim sub-files can be imported via the module's own imports (NOT via import-tree — they're HM modules, not flake-parts modules). Place them under `modules/neovim/_plugins/` or similar to avoid import-tree scanning them, OR use den aspect's `homeManager.imports`

  **Must NOT do**:
  - Do not change any neovim plugin configurations
  - Do not restructure plugin files unnecessarily

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: neovim config is 16+ files with complex imports — needs careful migration of the import chain
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12-13, 15-19)
  - **Blocks**: Tasks 20-23
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/neovim/default.nix` — Main neovim module (imports all plugins)
  - `profiles/neovim/` — 16+ plugin config files
  - nixvim input: `inputs.nixvim.homeModules.nixvim`

  **Acceptance Criteria**:
  - [ ] All neovim plugins configured
  - [ ] nixvim HM module imported

  **QA Scenarios**:
  ```
  Scenario: Nixvim enabled in home-manager
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.nixvim.enable" 2>&1`
      2. Assert true (or check that nixvim module is imported)
    Expected Result: Nixvim working
    Evidence: .sisyphus/evidence/task-14-neovim.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 15. Terminal aspects (ghostty, zellij, yazi, bat, fzf, ripgrep, zoxide)

  **What to do**:
  - Create `modules/terminal.nix` — den aspect for terminal tools HM config
  - Port: ghostty (`profiles/ghostty.nix`), bat (`profiles/bat.nix`), fzf (`profiles/fzf.nix`), ripgrep (`profiles/ripgrep.nix`), zoxide (`profiles/zoxide.nix`), yazi (`profiles/yazi.nix`)
  - Create `modules/zellij.nix` — separate aspect for zellij because it needs per-host behavior
  - Port `profiles/zellij.nix` but REMOVE the `osConfig.networking.hostName == "tahani"` check
  - Instead, the tahani-specific zellij auto-start behavior goes in Task 21 (tahani host aspect)

  **Must NOT do**:
  - Do not use hostname string comparisons
  - Do not change tool configurations

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12-14, 16-19)
  - **Blocks**: Tasks 20-25
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/zellij.nix` — Zellij with host-specific autostart check (line 20: `osConfig.networking.hostName == "tahani"`)
  - `profiles/ghostty.nix`, `profiles/bat.nix`, `profiles/fzf.nix`, `profiles/ripgrep.nix`, `profiles/zoxide.nix`, `profiles/yazi.nix`

  **Acceptance Criteria**:
  - [ ] All terminal tools configured
  - [ ] No hostname string comparisons in shared aspects
  - [ ] Zellij base config without host-specific auto-start

  **QA Scenarios**:
  ```
  Scenario: Terminal tools enabled
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.bat.enable" 2>&1`
      2. Assert true
    Expected Result: bat enabled in HM
    Evidence: .sisyphus/evidence/task-15-terminal.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 16. Communication aspects (himalaya, mbsync, ssh)

  **What to do**:
  - Create `modules/email.nix` — den aspect for email (himalaya + mbsync)
  - Port `profiles/himalaya.nix` — the himalaya HM module that creates a wrapper script (`writeShellApplication` around himalaya binary with IMAP password from sops)
  - Port `profiles/mbsync.nix` — mbsync HM config
  - CRITICAL: The himalaya wrapper package is currently accessed from NixOS scope in tahani (cross-module dependency). In den, instead create the wrapper within the `homeManager` class AND also make it available to the NixOS `nixos` class via the overlay package (himalaya overlay already exists). The inbox-triage systemd service in Task 21 should use `pkgs.himalaya` (from overlay) directly, not reach into HM config.
  - Create `modules/ssh-client.nix` — den aspect for SSH client config
  - Port `profiles/ssh.nix` — SSH client HM config with platform-conditional paths

  **Must NOT do**:
  - Do not create cross-module dependencies (HM → NixOS reads)
  - Do not change himalaya or mbsync settings

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Himalaya cross-dependency redesign is architecturally critical
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12-15, 17-19)
  - **Blocks**: Tasks 20, 21
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/himalaya.nix` — Himalaya HM module with writeShellApplication wrapper
  - `profiles/mbsync.nix` — mbsync config
  - `profiles/ssh.nix` — SSH client config with platform paths
  - `hosts/tahani/default.nix:9` — The cross-module dependency to eliminate: `himalaya = config.home-manager.users.${user}.programs.himalaya.package`
  - `overlays/himalaya.nix:1-3` — Himalaya overlay (packages from input)

  **Acceptance Criteria**:
  - [ ] Himalaya configured in HM
  - [ ] No cross-module HM→NixOS reads
  - [ ] SSH client configured with correct platform paths

  **QA Scenarios**:
  ```
  Scenario: Himalaya configured without cross-module dependency
    Tool: Bash
    Steps:
      1. Grep new modules/ for "config.home-manager.users"
      2. Assert zero matches (no HM config reads from NixOS scope)
    Expected Result: No cross-module dependency
    Evidence: .sisyphus/evidence/task-16-email.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 17. Desktop aspects (aerospace, home base)

  **What to do**:
  - Create `modules/desktop.nix` — den aspect for desktop/GUI HM config
  - Port `profiles/aerospace.nix` — AeroSpace tiling WM config (darwin-only HM module)
  - The wallpaper activation from `profiles/home.nix` is already in _lib/wallpaper.nix — wire it via the user aspect's darwin HM config
  - Include fonts.fontconfig.enable for darwin hosts (currently in chidi/jason host configs)

  **Must NOT do**:
  - Do not change aerospace settings

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12-16, 18-19)
  - **Blocks**: Tasks 22, 23
  - **Blocked By**: Tasks 7, 8, 10

  **References**:
  - `profiles/aerospace.nix` — AeroSpace WM config
  - `hosts/chidi/default.nix:50` — `fonts.fontconfig.enable = true`

  **Acceptance Criteria**:
  - [ ] AeroSpace configured in darwin HM
  - [ ] fonts.fontconfig.enable set for darwin hosts

  **QA Scenarios**:
  ```
  Scenario: AeroSpace configured for darwin hosts
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.aerospace.enable" 2>&1` (or check relevant config)
    Expected Result: AeroSpace enabled
    Evidence: .sisyphus/evidence/task-17-desktop.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 18. AI tools aspects (opencode, claude-code)

  **What to do**:
  - Create `modules/ai-tools.nix` — den aspect for AI coding tools
  - Port `profiles/opencode.nix` — references `inputs.llm-agents.packages...opencode`
  - Port `profiles/claude-code.nix` — references `inputs.llm-agents.packages...claude-code`
  - These need `inputs` access — use den's `inputs'` battery or access `inputs` from flake-parts module args
  - Use flake-file to declare llm-agents input dependency
  - NOTE: The opencode config may include `profiles/opencode/` directory content

  **Must NOT do**:
  - Do not change opencode or claude-code settings

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12-17, 19)
  - **Blocks**: Task 21 (tahani uses opencode in systemd service)
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/opencode.nix` — OpenCode HM config using inputs.llm-agents
  - `profiles/claude-code.nix` — Claude Code HM config using inputs.llm-agents
  - `profiles/opencode/` — OpenCode config directory (if exists)

  **Acceptance Criteria**:
  - [ ] Both AI tools configured in HM
  - [ ] inputs.llm-agents accessed correctly (not via specialArgs)

  **QA Scenarios**:
  ```
  Scenario: AI tools packages available
    Tool: Bash
    Steps:
      1. Verify opencode and claude-code are in home packages (nix eval)
    Expected Result: Both tools in user's home packages
    Evidence: .sisyphus/evidence/task-18-ai.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 19. Miscellaneous aspects (atuin, zk)

  **What to do**:
  - Create `modules/atuin.nix` — den aspect for atuin (shell history sync)
  - Port `profiles/atuin.nix` into `den.aspects.atuin.homeManager`
  - Create `modules/zk.nix` — den aspect for zk (zettelkasten)
  - Port `profiles/zk.nix` into `den.aspects.zk.homeManager`
  - Include both in user aspect

  **Must NOT do**:
  - Do not change settings

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12-18)
  - **Blocks**: Tasks 20-25
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `profiles/atuin.nix` — Atuin config
  - `profiles/zk.nix` — Zk zettelkasten config

  **Acceptance Criteria**:
  - [ ] Atuin and zk configured in HM

  **QA Scenarios**:
  ```
  Scenario: Atuin enabled
    Tool: Bash
    Steps:
      1. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.atuin.enable" 2>&1`
      2. Assert true
    Expected Result: Atuin enabled
    Evidence: .sisyphus/evidence/task-19-misc.txt
  ```

  **Commit**: NO (groups with Wave 3)

- [ ] 20. Server aspects — michael (gitea + litestream + restic)

  **What to do**:
  - Create `modules/michael.nix` — den aspect for michael host
  - Port michael-specific config into `den.aspects.michael`:
    - `nixos` class: import disko module (`inputs.disko.nixosModules.disko`), import disk-config.nix and hardware-configuration.nix (place originals under `modules/_hosts/michael/` with `_` prefix to avoid import-tree)
    - `nixos` class: gitea service config — absorb the entire `modules/gitea.nix` custom module into this aspect. The `my.gitea` options become direct service configuration (services.gitea, services.litestream, services.restic). Use SOPS secrets from Task 5.
    - `nixos` class: `modulesPath` imports (installer/scan/not-detected.nix, profiles/qemu-guest.nix)
    - `nixos` class: `networking.hostName = "michael"`
    - Include: nixos-system, core, openssh, fail2ban, tailscale aspects
  - HM: minimal imports — only nushell, home base, ssh, nixvim
  - Git email override: `homeManager.programs.git.settings.user.email` is NOT set (michael has no email override in current config)
  - Wire disko input via flake-file

  **Must NOT do**:
  - Do not change gitea service configuration values
  - Do not change disk-config or hardware-configuration
  - Do not create abstractions over gitea's backup system

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex server with custom gitea module absorption, disko, hardware config, and multiple service interactions
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 21-25)
  - **Blocks**: Task 27
  - **Blocked By**: Tasks 5, 9, 14, 16

  **References**:
  - `hosts/michael/default.nix:1-48` — Full michael host config
  - `hosts/michael/disk-config.nix` — Disko partition config
  - `hosts/michael/hardware-configuration.nix` — Hardware config
  - `modules/gitea.nix` — Custom my.gitea module (litestream, restic, s3) to absorb
  - `hosts/michael/secrets.nix:1-22` — SOPS secrets (already in Task 5)

  **Acceptance Criteria**:
  - [ ] `nix build ".#nixosConfigurations.michael.config.system.build.toplevel"` succeeds
  - [ ] Gitea service configured with litestream and restic
  - [ ] Disko disk-config preserved

  **QA Scenarios**:
  ```
  Scenario: Michael host builds successfully
    Tool: Bash
    Steps:
      1. Run `nix build ".#nixosConfigurations.michael.config.system.build.toplevel" --dry-run 2>&1`
      2. Assert exit code 0
    Expected Result: Michael builds without errors
    Evidence: .sisyphus/evidence/task-20-michael.txt

  Scenario: Gitea service configured
    Tool: Bash
    Steps:
      1. Run `nix eval ".#nixosConfigurations.michael.config.services.gitea.enable" 2>&1`
      2. Assert true
    Expected Result: Gitea enabled
    Evidence: .sisyphus/evidence/task-20-gitea.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 21. Server aspects — tahani (adguard, paperless, docker, inbox-triage)

  **What to do**:
  - Create `modules/tahani.nix` — den aspect for tahani host
  - Port tahani-specific config into `den.aspects.tahani`:
    - `nixos` class: import tahani-specific files (adguardhome.nix, cache.nix, networking.nix, paperless.nix — place under `modules/_hosts/tahani/`)
    - `nixos` class: `networking.hostName = "tahani"`, `virtualisation.docker.enable`, docker group for user
    - `nixos` class: swap device config
    - `nixos` class: **Inbox-triage systemd service** — REDESIGNED to avoid cross-module dependency:
      - Use `pkgs.himalaya` (from overlay, NOT from HM config) for the himalaya binary
      - Use `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode` for opencode binary
      - Define systemd service and timer exactly as current
    - Include: nixos-system, core, openssh, tailscale aspects
  - HM: all the profiles that tahani currently imports (most shared aspects + himalaya, mbsync)
  - HM: git email override: `homeManager.programs.git.settings.user.email = "christoph@schmatzler.com"`
  - HM: zellij auto-start override (the tahani-specific behavior from zellij.nix)

  **Must NOT do**:
  - Do not read HM config from NixOS scope (no `config.home-manager.users...`)
  - Do not change service configs (adguard, paperless, docker)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Most complex host — has the himalaya cross-dependency redesign, multiple services, and the most HM profiles
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 20, 22-25)
  - **Blocks**: Task 27
  - **Blocked By**: Tasks 5, 9, 16, 18

  **References**:
  - `hosts/tahani/default.nix:1-94` — Full tahani config with cross-module dependency
  - `hosts/tahani/adguardhome.nix` — AdGuard Home service config
  - `hosts/tahani/cache.nix` — Cache config
  - `hosts/tahani/networking.nix` — Network config
  - `hosts/tahani/paperless.nix` — Paperless-NGX service config
  - `profiles/zellij.nix:20` — The hostname check to replace with per-host override
  - `overlays/himalaya.nix` — Himalaya available as `pkgs.himalaya` via overlay

  **Acceptance Criteria**:
  - [ ] `nix build ".#nixosConfigurations.tahani.config.system.build.toplevel"` succeeds
  - [ ] Inbox-triage systemd service uses `pkgs.himalaya` (overlay), NOT HM config read
  - [ ] Zero instances of `config.home-manager.users` in any module
  - [ ] Zellij auto-start is tahani-specific (not hostname comparison)

  **QA Scenarios**:
  ```
  Scenario: Tahani builds without cross-module dependency
    Tool: Bash
    Steps:
      1. Run `nix build ".#nixosConfigurations.tahani.config.system.build.toplevel" --dry-run 2>&1`
      2. Assert exit code 0
      3. Grep modules/ for "config.home-manager.users"
      4. Assert zero matches
    Expected Result: Tahani builds, no HM→NixOS cross-reads
    Evidence: .sisyphus/evidence/task-21-tahani.txt

  Scenario: Docker enabled on tahani
    Tool: Bash
    Steps:
      1. Run `nix eval ".#nixosConfigurations.tahani.config.virtualisation.docker.enable" 2>&1`
      2. Assert true
    Expected Result: Docker enabled
    Evidence: .sisyphus/evidence/task-21-docker.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 22. Host aspects — chidi (work-specific)

  **What to do**:
  - Create `modules/chidi.nix` — den aspect for chidi (work laptop)
  - Define `den.aspects.chidi`:
    - Include: darwin-system, core, tailscale, all shared user aspects
    - `darwin` class: `environment.systemPackages = [pkgs.slack]` (work-specific)
    - `darwin` class: `networking.hostName = "chidi"`, `networking.computerName = "chidi"`
    - `homeManager` class: `programs.git.settings.user.email = "christoph@tuist.dev"` (work email)
    - `homeManager` class: `fonts.fontconfig.enable = true`

  **Must NOT do**:
  - Do not add work-specific packages beyond Slack
  - Do not change git email

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 20-21, 23-25)
  - **Blocks**: Task 27
  - **Blocked By**: Tasks 5, 8, 17

  **References**:
  - `hosts/chidi/default.nix:1-57` — Current chidi config
  - `hosts/chidi/secrets.nix:1-5` — Already handled in Task 5

  **Acceptance Criteria**:
  - [ ] `nix build ".#darwinConfigurations.chidi.system"` succeeds
  - [ ] Slack in systemPackages
  - [ ] Git email = "christoph@tuist.dev"

  **QA Scenarios**:
  ```
  Scenario: Chidi builds with work email
    Tool: Bash
    Steps:
      1. Run `nix build ".#darwinConfigurations.chidi.system" --dry-run 2>&1`
      2. Assert exit code 0
      3. Run `nix eval ".#darwinConfigurations.chidi.config.home-manager.users.cschmatzler.programs.git.settings.user.email" 2>&1`
      4. Assert output is "christoph@tuist.dev"
    Expected Result: Chidi builds, work email set
    Evidence: .sisyphus/evidence/task-22-chidi.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 23. Host aspects — jason (personal-specific)

  **What to do**:
  - Create `modules/jason.nix` — den aspect for jason (personal laptop)
  - Define `den.aspects.jason`:
    - Include: darwin-system, core, tailscale, all shared user aspects
    - `darwin` class: `networking.hostName = "jason"`, `networking.computerName = "jason"`
    - `homeManager` class: `programs.git.settings.user.email = "christoph@schmatzler.com"` (personal email)
    - `homeManager` class: `fonts.fontconfig.enable = true`

  **Must NOT do**:
  - Do not add packages not in current jason config

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 20-22, 24-25)
  - **Blocks**: Task 27
  - **Blocked By**: Tasks 5, 8, 17

  **References**:
  - `hosts/jason/default.nix:1-52` — Current jason config

  **Acceptance Criteria**:
  - [ ] `nix build ".#darwinConfigurations.jason.system"` succeeds
  - [ ] Git email = "christoph@schmatzler.com"

  **QA Scenarios**:
  ```
  Scenario: Jason builds with personal email
    Tool: Bash
    Steps:
      1. Run `nix build ".#darwinConfigurations.jason.system" --dry-run 2>&1`
      2. Assert exit code 0
    Expected Result: Jason builds successfully
    Evidence: .sisyphus/evidence/task-23-jason.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 24. Network aspects (openssh, fail2ban, tailscale, postgresql)

  **What to do**:
  - Create `modules/network.nix` — den aspect for network services
  - Port `profiles/openssh.nix` → `den.aspects.openssh.nixos` (SSH server config)
  - Port `profiles/fail2ban.nix` → `den.aspects.fail2ban.nixos`
  - Port `profiles/tailscale.nix` → `den.aspects.tailscale` with per-class configs (nixos + darwin support, uses `lib.optionalAttrs pkgs.stdenv.isLinux` currently — convert to per-class)
  - Port `profiles/postgresql.nix` → `den.aspects.postgresql.nixos` (if used by any host)
  - Include these in appropriate host aspects

  **Must NOT do**:
  - Do not change SSH, fail2ban, or tailscale settings

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 20-23, 25)
  - **Blocks**: Task 27
  - **Blocked By**: Task 9

  **References**:
  - `profiles/openssh.nix` — OpenSSH server config
  - `profiles/fail2ban.nix` — Fail2ban config
  - `profiles/tailscale.nix` — Tailscale with platform conditionals
  - `profiles/postgresql.nix` — PostgreSQL config

  **Acceptance Criteria**:
  - [ ] All network services configured
  - [ ] Tailscale works on both darwin and nixos

  **QA Scenarios**:
  ```
  Scenario: Tailscale enabled on all hosts
    Tool: Bash
    Steps:
      1. Run `nix eval ".#nixosConfigurations.michael.config.services.tailscale.enable" 2>&1`
      2. Assert true
    Expected Result: Tailscale enabled
    Evidence: .sisyphus/evidence/task-24-network.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 25. Packages aspect (system packages list)

  **What to do**:
  - Ensure the home.packages list from `_lib/packages.nix` is wired into the user aspect
  - The `callPackage` pattern for packages.nix should be replicated — import `_lib/packages.nix` and pass required args
  - Ensure platform-conditional packages (`lib.optionals stdenv.isDarwin/isLinux`) are preserved
  - Remove colmena from the package list, add deploy-rs CLI if needed

  **Must NOT do**:
  - Do not add packages not in current packages.nix (except deploy-rs CLI)
  - Do not remove colmena replacement from packages without confirming

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 20-24)
  - **Blocks**: Task 27
  - **Blocked By**: Task 7

  **References**:
  - `profiles/packages.nix` — Full package list (moved to _lib/packages.nix in Task 3)
  - `profiles/home.nix:13` — `home.packages = pkgs.callPackage ./packages.nix {inherit inputs;};`

  **Acceptance Criteria**:
  - [ ] All packages from current list present
  - [ ] Platform-conditional packages preserved

  **QA Scenarios**:
  ```
  Scenario: Home packages include expected tools
    Tool: Bash
    Steps:
      1. Verify packages.nix is loaded and packages are in home.packages
    Expected Result: Packages available
    Evidence: .sisyphus/evidence/task-25-packages.txt
  ```

  **Commit**: NO (groups with Wave 4)

- [ ] 26. Remove old structure

  **What to do**:
  - Delete `hosts/` directory entirely
  - Delete `profiles/` directory entirely
  - Delete `modules/_legacy/` directory (old NixOS modules moved here by Task 1, now fully absorbed into den aspects)
  - Delete `overlays/` directory entirely (now in modules/overlays.nix)
  - Delete `lib/` directory entirely (now in modules/_lib/)
  - Keep `secrets/` directory (encrypted files, unchanged)
  - Keep `apps/` directory (rewritten to Nushell by Task 29)
  - Keep `.sops.yaml` (unchanged)
  - Verify no broken references remain

  **Must NOT do**:
  - Do not delete `secrets/`, `apps/`, `.sops.yaml`, or `alejandra.toml`

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`git-master`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5 (after Task 27 confirms all builds pass)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 27

  **References**:
  - All old directories to remove: hosts/, profiles/, overlays/, lib/

  **Acceptance Criteria**:
  - [ ] Old directories removed
  - [ ] `nix flake check` still passes after removal
  - [ ] No broken file references

  **QA Scenarios**:
  ```
  Scenario: Old structure removed, builds still pass
    Tool: Bash
    Steps:
      1. Verify hosts/ directory doesn't exist
      2. Verify profiles/ directory doesn't exist
      3. Run `nix flake check --no-build 2>&1`
      4. Assert exit code 0
    Expected Result: Clean structure, still evaluates
    Evidence: .sisyphus/evidence/task-26-cleanup.txt
  ```

  **Commit**: YES
  - Message: `chore: remove old host-centric structure`
  - Files: deleted directories
  - Pre-commit: `nix flake check --no-build && alejandra --check .`

- [ ] 27. Full build verification all 4 hosts

  **What to do**:
  - Build ALL 4 host configurations (or dry-run if cross-platform):
    - `nix build ".#darwinConfigurations.chidi.system" --dry-run`
    - `nix build ".#darwinConfigurations.jason.system" --dry-run`
    - `nix build ".#nixosConfigurations.michael.config.system.build.toplevel" --dry-run`
    - `nix build ".#nixosConfigurations.tahani.config.system.build.toplevel" --dry-run`
  - Run `nix flake check`
  - Run `alejandra --check .`
  - Verify deploy-rs nodes: `nix eval ".#deploy.nodes" --json`
  - Verify zero specialArgs: grep for specialArgs in all .nix files
  - Verify no hostname comparisons in shared aspects
  - Verify no HM→NixOS cross-reads

  **Must NOT do**:
  - Do not skip any host build

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Comprehensive verification requiring multiple build commands and assertions
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5 (after all implementation)
  - **Blocks**: Tasks 26, 28, F1-F4
  - **Blocked By**: Tasks 20-25

  **References**:
  - Definition of Done section of this plan
  - All acceptance criteria from all tasks

  **Acceptance Criteria**:
  - [ ] All 4 hosts build (or dry-run) successfully
  - [ ] `nix flake check` passes
  - [ ] `alejandra --check .` passes
  - [ ] deploy-rs nodes exist for michael and tahani
  - [ ] Zero specialArgs usage in codebase
  - [ ] Zero hostname string comparisons in shared modules

  **QA Scenarios**:
  ```
  Scenario: Complete build verification
    Tool: Bash
    Steps:
      1. Build all 4 hosts (dry-run)
      2. Run nix flake check
      3. Run alejandra --check .
      4. Eval deploy-rs nodes
      5. Grep for specialArgs — assert 0 matches
      6. Grep for "networking.hostName ==" in shared modules — assert 0 matches
    Expected Result: All checks pass
    Evidence: .sisyphus/evidence/task-27-verification.txt
  ```

  **Commit**: NO

- [ ] 28. Formatting pass + final cleanup

  **What to do**:
  - Run `alejandra .` to format all files
  - Remove any TODO comments or placeholder code
  - Verify `modules/` directory structure is clean
  - Ensure `.sops.yaml` still references correct secret file paths
  - Final `nix flake check`

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5 (after Task 27)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 27

  **References**:
  - `alejandra.toml` — Formatter config (tabs for indentation)

  **Acceptance Criteria**:
  - [ ] `alejandra --check .` passes
  - [ ] No TODO/FIXME/HACK comments

  **QA Scenarios**:
  ```
  Scenario: All files formatted
    Tool: Bash
    Steps:
      1. Run `alejandra --check . 2>&1`
      2. Assert exit code 0
    Expected Result: All files pass formatter
    Evidence: .sisyphus/evidence/task-28-format.txt
  ```

  **Commit**: YES
  - Message: `feat: rewrite config with den framework`
  - Files: all modules/*, flake.nix, flake.lock
  - Pre-commit: `nix flake check && alejandra --check .`

- [ ] 29. Rewrite apps/ scripts from bash to Nushell

  **What to do**:
  - Rewrite `apps/common.sh` → `apps/common.nu` — convert colored output helper functions (`print_info`, `print_success`, `print_error`, `print_warning`) to Nushell using `ansi` commands
  - Rewrite all 4 darwin scripts (`apps/aarch64-darwin/{build,apply,build-switch,rollback}`) from bash to Nushell:
    - `build`: hostname detection via `scutil --get LocalHostName` (fallback `hostname -s`), `nix build` darwin config, unlink result
    - `apply`: hostname detection, `nix run nix-darwin -- switch`
    - `build-switch`: hostname detection, `nix build` then `sudo darwin-rebuild switch`, unlink result
    - `rollback`: list generations via `darwin-rebuild --list-generations`, prompt for generation number via `input`, switch to it
  - Rewrite all 4 linux scripts (`apps/x86_64-linux/{build,apply,build-switch,rollback}`) from bash to Nushell:
    - `build`: hostname via `hostname`, `nix build` nixos config, unlink result
    - `apply`: hostname, sudo-aware `nixos-rebuild switch`
    - `build-switch`: hostname, `nix build` then sudo-aware `nixos-rebuild switch`
    - `rollback`: list generations via sudo-aware `nix-env --profile ... --list-generations`, prompt for number via `input`, sudo-aware switch-generation + switch-to-configuration
  - All scripts get `#!/usr/bin/env nu` shebang
  - Delete `apps/common.sh` after `apps/common.nu` is created
  - Use `use ../common.nu *` (or equivalent) to import shared helpers in each script
  - Preserve exact same behavior — same commands, same output messages, same error handling
  - Handle sudo checks in linux scripts: use `(id -u)` or `$env.EUID` equivalent in Nushell

  **Must NOT do**:
  - Do not change any nix build/switch/rebuild commands — only the shell scripting around them changes
  - Do not add new functionality beyond what exists in the bash scripts
  - Do not change the file names (the perSystem apps module references them by path)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward 1:1 rewrite of 9 small scripts (~186 lines total) from bash to Nushell. No architectural decisions needed.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 20-25)
  - **Blocks**: Task 27 (build verification should confirm apps still work)
  - **Blocked By**: Task 11 (perSystem apps module must be in place first)

  **References**:

  **Pattern References**:
  - `apps/common.sh` — Current colored output helpers (23 lines) — rewrite to Nushell `ansi` equivalents
  - `apps/aarch64-darwin/build` — Darwin build script (16 lines) — template for all darwin scripts
  - `apps/x86_64-linux/build` — Linux build script (16 lines) — template for all linux scripts
  - `apps/x86_64-linux/rollback` — Most complex script (30 lines, sudo checks, interactive input) — key test case

  **API/Type References**:
  - `modules/apps.nix` (created by Task 11) — perSystem apps module that references these scripts by path

  **External References**:
  - Nushell documentation: https://www.nushell.sh/book/ — Language reference for bash→nu translation
  - Nushell `ansi` command: for colored output (replaces ANSI escape codes)
  - Nushell `input` command: for interactive prompts (replaces bash `read -r`)

  **Acceptance Criteria**:
  - [ ] All 9 scripts rewritten with `#!/usr/bin/env nu` shebang
  - [ ] `apps/common.nu` exists with colored output helpers
  - [ ] `apps/common.sh` deleted
  - [ ] `nix run ".#build" -- --help 2>&1` doesn't error (script is parseable by nu)
  - [ ] `nix run ".#apply" -- --help 2>&1` doesn't error
  - [ ] No bash files remain in `apps/` directory

  **QA Scenarios**:
  ```
  Scenario: All apps/ scripts are valid Nushell
    Tool: Bash
    Preconditions: Task 11 (perSystem apps module) complete, all scripts rewritten
    Steps:
      1. Run `find apps/ -type f -name "*.sh" 2>&1` — assert no .sh files remain
      2. Run `head -1 apps/aarch64-darwin/build` — assert contains "#!/usr/bin/env nu"
      3. Run `head -1 apps/x86_64-linux/build` — assert contains "#!/usr/bin/env nu"
      4. Run `nu -c 'source apps/common.nu; print_info "test"' 2>&1` — assert exit code 0 and output contains "[INFO]"
      5. Run `nu -c 'source apps/common.nu; print_error "test"' 2>&1` — assert exit code 0 and output contains "[ERROR]"
    Expected Result: All scripts are Nushell, common.nu functions work
    Failure Indicators: Any .sh file found, shebang mismatch, nu parse errors
    Evidence: .sisyphus/evidence/task-29-nushell-scripts.txt

  Scenario: perSystem apps still reference correct scripts
    Tool: Bash
    Preconditions: Apps module (Task 11) and scripts (Task 29) both complete
    Steps:
      1. Run `nix eval ".#apps.x86_64-linux" --json 2>&1 | nu -c '$in | from json | columns | sort'`
      2. Assert output contains: apply, build, build-switch, rollback
      3. Run `nix eval ".#apps.aarch64-darwin" --json 2>&1 | nu -c '$in | from json | columns | sort'`
      4. Assert output contains: apply, build, build-switch, rollback
    Expected Result: All 4 apps registered on both platforms
    Failure Indicators: Missing app entries, nix eval errors
    Evidence: .sisyphus/evidence/task-29-apps-registered.txt
  ```

  **Commit**: YES
  - Message: `refactor: rewrite app scripts from bash to nushell`
  - Files: `apps/common.nu`, `apps/aarch64-darwin/*`, `apps/x86_64-linux/*`
  - Pre-commit: `nu -c 'source apps/common.nu'`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (nix eval, read file). For each "Must NOT Have": search codebase for forbidden patterns (specialArgs, hostname comparisons, HM→NixOS cross-reads). Check all 4 hosts build. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `alejandra --check .` + `nix flake check`. Review all new modules for: dead code, unused imports, inconsistent patterns, hardcoded values that should be options. Check den API usage is idiomatic. Verify import-tree conventions (no function files in import paths).
  Output: `Format [PASS/FAIL] | Check [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Build all 4 hosts. Verify deploy-rs nodes exist via nix eval. Verify SOPS secrets preserved via nix eval. Verify git email overrides. Verify overlays produce correct packages. Verify no specialArgs usage anywhere. Save evidence to `.sisyphus/evidence/final-qa/`.
  Output: `Builds [4/4 pass] | Deploy [2/2] | Secrets [N/N] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", verify actual implementation matches 1:1. Check "Must NOT Have" compliance — no new packages, no new services, no abstractions. Verify every current profile has a corresponding den aspect. Flag any behavioral differences.
  Output: `Tasks [N/N compliant] | Scope [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

Since this is a clean rewrite, the work should be committed as a small series of logical commits:

- **1**: `feat: rewrite config with den framework` — All new modules, flake.nix
- **2**: `refactor: rewrite app scripts from bash to nushell` — apps/ directory
- **3**: `chore: remove old host-centric structure` — Delete hosts/, profiles/, modules/_legacy/
- Pre-commit: `alejandra --check . && nix flake check`

---

## Success Criteria

### Verification Commands
```bash
nix build ".#darwinConfigurations.chidi.system"         # Expected: builds successfully
nix build ".#darwinConfigurations.jason.system"          # Expected: builds successfully
nix build ".#nixosConfigurations.michael.config.system.build.toplevel"  # Expected: builds successfully
nix build ".#nixosConfigurations.tahani.config.system.build.toplevel"   # Expected: builds successfully
nix flake check                                          # Expected: passes
alejandra --check .                                      # Expected: passes
nix eval ".#deploy.nodes.michael" --json                 # Expected: valid deploy-rs node
nix eval ".#deploy.nodes.tahani" --json                  # Expected: valid deploy-rs node
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All 4 hosts build
- [ ] Zero specialArgs usage
- [ ] SOPS paths identical to current
- [ ] deploy-rs configured for NixOS hosts
- [ ] All overlays functional
- [ ] Formatting passes
