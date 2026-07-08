{...}: {
  den.aspects.opencode.homeManager = {
    config,
    lib,
    pkgs,
    inputs',
    ...
  }: let
    skills = {
      ".config/opencode/skills/wrdn-authz" = {
        source = ./_skills/wrdn-authz;
        recursive = true;
      };
      ".config/opencode/skills/wrdn-code-execution" = {
        source = ./_skills/wrdn-code-execution;
        recursive = true;
      };
      ".config/opencode/skills/wrdn-data-exfil" = {
        source = ./_skills/wrdn-data-exfil;
        recursive = true;
      };
      ".config/opencode/skills/wrdn-gha-workflows" = {
        source = ./_skills/wrdn-gha-workflows;
        recursive = true;
      };
      ".config/opencode/skills/wrdn-pii" = {
        source = ./_skills/wrdn-pii;
        recursive = true;
      };
    };
    jsonFormat = pkgs.formats.json {};
    nonoProfile = {
      meta = {
        name = "opencode";
        version = "1.0.0";
        description = "OpenCode coding agent profile with restricted network, OpenCode/OpenAI access, executor.sh MCP access, and NixOS development tooling.";
      };

      extends = "default";

      groups.include = [
        "git_config"
        "go_runtime"
        "java_runtime"
        "linux_runtime_state"
        "linux_sysfs_read"
        "linux_temp_read"
        "nix_runtime"
        "node_runtime"
        "python_runtime"
        "rust_runtime"
        "user_caches_linux"
      ];

      workdir.access = "readwrite";

      filesystem = {
        allow = [
          "$HOME/.cache/opencode"
          "$HOME/.codex"
          "$HOME/.config/opencode"
          "$HOME/.local/share/opencode"
          "$HOME/.local/state/opencode"
          "$HOME/.npm"
          "$HOME/.npm-global"
          "$HOME/Projects/worktrees"
        ];
        read = [
          "$HOME/.config/nix"
          "$HOME/.local/state/nix"
        ];
        unix_socket = [
          "$HOME/.config/herdr/herdr.sock"
        ];
        bypass_protection = [
          "$HOME/.codex"
          "$HOME/.config/opencode"
        ];
      };

      security = {
        process_info_mode = "isolated";
        signal_mode = "isolated";
        wsl2_proxy_policy = "error";
      };

      network = {
        network_profile = "codex";
        allow_domain = [
          "auth.openai.com"
          "chatgpt.com"
          "console.opencode.ai"
          "opencode.ai"
          "*.opencode.ai"
          "executor.sh"
          "*.executor.sh"
          "api.github.com"
          "cache.nixos.org"
          "codeload.github.com"
          "crates.io"
          "files.pythonhosted.org"
          "github.com"
          "index.crates.io"
          "npm.pkg.github.com"
          "nono.sh"
          "objects.githubusercontent.com"
          "proxy.golang.org"
          "pypi.org"
          "raw.githubusercontent.com"
          "registry.npmjs.org"
          "static.crates.io"
          "sum.golang.org"
        ];
        open_port = [
          3000
          5173
          8000
          8080
        ];
      };

      environment.allow_vars = [
        "COLORTERM"
        "EDITOR"
        "HERDR_*"
        "HOME"
        "LANG"
        "LC_*"
        "NIX_*"
        "NIXOS_*"
        "OPENCODE_*"
        "PATH"
        "SHELL"
        "SSH_AUTH_SOCK"
        "TERM"
        "TERM_PROGRAM"
        "TMPDIR"
        "USER"
        "XDG_*"
      ];
    };
    commands = import ./_opencode/commands.nix {};
    commandFiles =
      lib.mapAttrs' (
        name: text:
          lib.nameValuePair ".config/opencode/commands/${name}.md" {
            inherit text;
          }
      )
      commands;
    configs = {
      ".config/opencode/opencode.jsonc".source = jsonFormat.generate "opencode.jsonc" (import ./_opencode/settings.nix {});
      ".config/opencode/tui.json".source = jsonFormat.generate "opencode-tui.json" (import ./_opencode/tui.nix {});
      ".config/nono/profiles/opencode.json".source = jsonFormat.generate "nono-opencode-profile.json" nonoProfile;
    };
  in {
    home.packages = [
      inputs'.llm-agents.packages.opencode
      pkgs.nodejs_24
      pkgs.nono
      pkgs.plannotator
    ];

    home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    home.sessionVariables.PLANNOTATOR_PORT = "19432";
    home.sessionVariables.PLANNOTATOR_REMOTE = "1";
    home.shellAliases.nopencode = "nono run --profile opencode --allow-cwd -- opencode";

    home.file =
      skills
      // commandFiles
      // configs;
  };
}
