{...}: {
  den.aspects.codex.homeManager = {
    config,
    lib,
    pkgs,
    inputs',
    ...
  }: let
    jsonFormat = pkgs.formats.json {};
    tomlFormat = pkgs.formats.toml {};
    commands = import ./_codex/commands.nix {};
    commandFiles =
      lib.mapAttrs' (
        name: text:
          lib.nameValuePair ".codex/prompts/${name}.md" {
            inherit text;
          }
      )
      commands;
    nonoProfile = {
      meta = {
        name = "codex";
        version = "1.0.0";
        description = "Codex CLI coding agent profile with restricted network, Codex/OpenAI access, executor.sh MCP access, and NixOS development tooling.";
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
          "$HOME/.cache/codex"
          "$HOME/.codex"
          "$HOME/.local/share/codex"
          "$HOME/.local/state/codex"
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
          "api.openai.com"
          "auth.openai.com"
          "chatgpt.com"
          "*.chatgpt.com"
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
          "openai.com"
          "*.openai.com"
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
        "OPENAI_*"
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
    configs = {
      ".codex/config.toml".source = tomlFormat.generate "codex-config.toml" (import ./_codex/settings.nix {
        homeDirectory = config.home.homeDirectory;
      });
      ".config/nono/profiles/codex.json".source = jsonFormat.generate "nono-codex-profile.json" nonoProfile;
    };
  in {
    home.packages = [
      inputs'.llm-agents.packages.codex
      pkgs.nodejs_24
      pkgs.nono
    ];

    home.sessionVariables.NPM_CONFIG_PREFIX = lib.mkDefault "${config.home.homeDirectory}/.npm-global";
    home.shellAliases.ncodex = "nono run --profile codex --allow-cwd -- codex";

    home.file = commandFiles // configs;
  };
}
