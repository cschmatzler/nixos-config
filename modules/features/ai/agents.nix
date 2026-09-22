{
  den,
  inputs,
  ...
}: let
  local = import ../../_lib/local.nix;
in {
  flake-file.inputs = {
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dmmulroy-skills = {
      url = "github:dmmulroy/skills";
      flake = false;
    };
    humanlayer-skills = {
      url = "github:humanlayer/skills";
      flake = false;
    };
  };

  den.aspects.agents = {
    includes = [den.aspects.dev-tools];

    os = {config, ...}: {
      environment.etc."codex/config.toml".source =
        config.home-manager.users.${local.user.name}.home.file.".codex/config.toml".source;
    };

    homeManager = {
      inputs',
      lib,
      pkgs,
      ...
    }: let
      # Override llm-agents until its Claude Code package catches up.
      claudeVersion = "2.1.280";
      claudePlatforms = {
        aarch64-darwin = {
          platform = "darwin-arm64";
          hash = "sha256:387a5c5dcdbb815085edf0baf79591f9d8894efe922bceaf3d75b1b08055229d";
        };
        aarch64-linux = {
          platform = "linux-arm64";
          hash = "sha256:92f2b4fd05d0bdcf7b9a0d4e0ecef4a1e4b368b290cd8fd07cff9a50013f45a2";
        };
        x86_64-linux = {
          platform = "linux-x64";
          hash = "sha256:1e08503dbdf3c2cb0d706d32f3408277388d1c76ef108673e8fe42c1b322925b";
        };
      };
      claudeSource = system: let
        inherit (claudePlatforms.${system}) platform hash;
      in
        pkgs.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${claudeVersion}/${platform}/claude";
          inherit hash;
        };
      skillDirs = path:
        lib.mapAttrs (name: _: path + "/${name}")
        (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
      skills =
        skillDirs ./_agents/skills
        // {
          bro = inputs.dmmulroy-skills + "/bro";
          effect-service-design = inputs.dmmulroy-skills + "/effect-service-design";
          show-me = inputs.humanlayer-skills + "/plugins/show-me/skills/show-me";
        };
    in {
      programs.mcp = {
        enable = true;
        servers = {
          opensrc = {
            command = "npx";
            args = ["-y" "opensrc-mcp"];
          };
          executor.url = "https://executor.sh/mcp?search_tools=true";
        };
      };

      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code.overrideAttrs {
          version = claudeVersion;
          src = claudeSource pkgs.stdenv.hostPlatform.system;
          codesignSources = [(claudeSource "aarch64-darwin")];
        };
        enableMcpIntegration = true;
        commandsDir = ./_agents/prompts;
        inherit skills;
        settings.attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
      };

      programs.codex = {
        enable = true;
        package = inputs'.llm-agents.packages.codex;
        enableMcpIntegration = true;
        inherit skills;
      };
      home.file.".codex/config.toml".enable = false;
      home.file.".codex/prompts".source = ./_agents/prompts;

      programs.opencode = {
        enable = true;
        package = inputs'.llm-agents.packages.opencode;
        enableMcpIntegration = true;
        commands = ./_agents/prompts;
        inherit skills;
      };
    };
  };
}
