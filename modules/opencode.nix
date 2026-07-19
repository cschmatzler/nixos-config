_: let
  local = import ./_lib/local.nix;
  secretLib = import ./_lib/secrets.nix {};
  apiKeyPath = local.secretPath "opencode-api-key";
in {
  den.aspects.opencode = {
    os.sops.secrets.opencode-api-key = secretLib.mkUserBinarySecret {
      name = "opencode-api-key";
      sopsFile = ../secrets/opencode-api-key;
    };

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
      skillFiles =
        builtins.listToAttrs (map (name: {
            name = ".config/opencode/skills/${name}";
            value = {
              source = ./_skills + "/${name}";
              recursive = true;
            };
          })
          skillNames)
        // {
          ".config/opencode/skills/hunk-review/SKILL.md".source = "${inputs'.hunk.packages.hunk}/skills/hunk-review/SKILL.md";
        };
      sideshow = pkgs.callPackage ./_packages/sideshow.nix {};
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        model = "openai/gpt-5.6-sol";
        autoupdate = false;
        share = "manual";
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
        mcp = import ./_opencode/mcp.nix {inherit sideshow;};
        permission = {
          bash."*--no-verify*" = "deny";
          skill = {
            "coding-standards" = "allow";
            effect = "allow";
            herdr = "allow";
            "hunk-review" = "allow";
            "wrdn-*" = "allow";
          };
        };
      };
      tuiSettings = import ./_opencode/tui.nix;
      nonoProfile = import ./_opencode/nono-profile.nix;
      configs = {
        ".config/opencode/opencode.jsonc".source = jsonFormat.generate "opencode.jsonc" settings;
        ".config/opencode/tui.json".source = jsonFormat.generate "opencode-tui.json" tuiSettings;
        ".config/nono/profiles/opencode.json".source = jsonFormat.generate "nono-opencode-profile.json" nonoProfile;
      };
    in {
      programs.fish.shellInit = lib.mkAfter ''
        if test -f "${apiKeyPath}"
          set -gx OPENCODE_API_KEY (string trim -- (cat "${apiKeyPath}"))
        end
      '';

      home = {
        packages =
          [
            inputs'.llm-agents.packages.opencode
            sideshow
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [
            pkgs.xdg-utils
          ];
        shellAliases.nopencode = "nono run --profile opencode --allow-cwd -- opencode";
        file =
          commandFiles
          // skillFiles
          // configs;
      };
    };
  };
}
