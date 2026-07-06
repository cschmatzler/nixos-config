{...}: {
  den.aspects.pi.homeManager = {
    config,
    lib,
    pkgs,
    inputs',
    ...
  }: let
    skills = {
      ".pi/agent/skills/wrdn-authz" = {
        source = ./_skills/wrdn-authz;
        recursive = true;
      };
      ".pi/agent/skills/wrdn-code-execution" = {
        source = ./_skills/wrdn-code-execution;
        recursive = true;
      };
      ".pi/agent/skills/wrdn-data-exfil" = {
        source = ./_skills/wrdn-data-exfil;
        recursive = true;
      };
      ".pi/agent/skills/wrdn-gha-workflows" = {
        source = ./_skills/wrdn-gha-workflows;
        recursive = true;
      };
      ".pi/agent/skills/wrdn-pii" = {
        source = ./_skills/wrdn-pii;
        recursive = true;
      };
    };
    jsonFormat = pkgs.formats.json {};
    nonoProfile = {
      meta = {
        name = "pi";
        version = "1.0.0";
        description = "Pi coding agent profile with restricted network, Codex/OpenAI access, executor.sh MCP access, and NixOS development tooling.";
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
          "$HOME/.cache/pi"
          "$HOME/.codex"
          "$HOME/.local/share/pi"
          "$HOME/.npm"
          "$HOME/.npm-global"
          "$HOME/.pi"
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
          "$HOME/.pi"
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
          "pi.dev"
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
    prompts = import ./_pi/prompts.nix {};
    promptFiles =
      lib.mapAttrs' (
        name: text:
          lib.nameValuePair ".pi/agent/prompts/${name}.md" {
            inherit text;
          }
      )
      prompts;
    configs = {
      ".pi/agent/settings.json".source = jsonFormat.generate "pi-agent-settings.json" (import ./_pi/settings.nix {
        inherit config;
      });
      ".pi/agent/mcp.json".source = jsonFormat.generate "pi-agent-mcp.json" (import ./_pi/mcp.nix {
        inherit lib pkgs;
      });
      ".config/nono/profiles/pi.json".source = jsonFormat.generate "nono-pi-profile.json" nonoProfile;
    };
  in {
    home.packages = [
      inputs'.llm-agents.packages.pi
      pkgs.nono
      pkgs.plannotator
    ];

    home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    home.shellAliases.npi = "nono run --profile pi --allow-cwd -- pi";
    home.sessionVariables.PLANNOTATOR_PORT = "19432";
    home.sessionVariables.PLANNOTATOR_REMOTE = "1";

    home.file =
      skills
      // promptFiles
      // configs;
  };
}
