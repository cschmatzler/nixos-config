_: {
  den.aspects.opencode = {
    homeManager = {
      inputs',
      lib,
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      commands = import ./_opencode/commands.nix;
      skillNames = [
        "coding-standards"
        "effect"
        "herdr"
        "rmslop"
        "wrdn-authz"
        "wrdn-code-execution"
        "wrdn-data-exfil"
        "wrdn-gha-workflows"
        "wrdn-pii"
      ];
      commandFiles =
        lib.mapAttrs' (
          name: text:
            lib.nameValuePair ".config/opencode/command/${name}.md" {
              inherit text;
            }
        )
        commands;
      skillFiles = builtins.listToAttrs (map (name: {
          name = ".config/opencode/skills/${name}";
          value = {
            source = ./_skills + "/${name}";
            recursive = true;
          };
        })
        skillNames);
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        model = "openai/gpt-5.6-sol";
        autoupdate = false;
        share = "manual";
        plugin = [
          "@plannotator/opencode@0.24.2"
          "opencode-claude-auth@2.1.4"
        ];
        agent = {
          build = {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          };
          explore.disable = true;
          general.disable = true;
          plan = {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          };
        };
        mcp = (import ./_lib/mcp.nix).opencode;
        permission = {
          bash."*--no-verify*" = "deny";
          skill = {
            "coding-standards" = "allow";
            effect = "allow";
            herdr = "allow";
            "wrdn-*" = "allow";
          };
        };
      };
      tuiSettings = import ./_opencode/tui.nix;
      tuiTheme = import ./_opencode/rose-pine-dawn.nix;
      configs = {
        ".config/opencode/opencode.jsonc".source = jsonFormat.generate "opencode.jsonc" settings;
        ".config/opencode/tui.json".source = jsonFormat.generate "opencode-tui.json" tuiSettings;
        ".config/opencode/themes/rose-pine-dawn.json".source = jsonFormat.generate "opencode-rose-pine-dawn.json" tuiTheme;
      };
    in {
      home = {
        sessionVariables = {
          PLANNOTATOR_PORT = "20000";
          PLANNOTATOR_REMOTE = "1";
        };
        packages =
          [
            inputs'.llm-agents.packages.opencode
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [
            pkgs.xdg-utils
          ];
        file =
          commandFiles
          // skillFiles
          // configs;
      };
    };
  };
}
