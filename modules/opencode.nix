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
      lib,
      pkgs,
      inputs',
      ...
    }: let
      skillNames = [
        "wrdn-authz"
        "wrdn-code-execution"
        "wrdn-data-exfil"
        "wrdn-gha-workflows"
        "wrdn-pii"
      ];
      skills = builtins.listToAttrs (map (name: {
          name = ".config/opencode/skills/${name}";
          value = {
            source = ./_skills + "/${name}";
            recursive = true;
          };
        })
        skillNames);
      jsonFormat = pkgs.formats.json {};
      mkNonoProfile = import ./_ai/nono-profile.nix;
      nonoProfile = mkNonoProfile {
        name = "opencode";
        description = "OpenCode coding agent profile with restricted network, OpenCode/OpenAI access, executor.sh MCP access, and NixOS development tooling.";
        writablePaths = [
          "$HOME/.cache/opencode"
          "$HOME/.config/opencode"
          "$HOME/.local/share/opencode"
          "$HOME/.local/state/opencode"
        ];
        bypassProtection = [
          "$HOME/.config/opencode"
        ];
        serviceDomains = [
          "auth.openai.com"
          "chatgpt.com"
          "console.opencode.ai"
          "opencode.ai"
          "*.opencode.ai"
        ];
        apiEnvironmentVariables = [
          "OPENCODE_*"
        ];
      };
      commands = import ./_ai/commands.nix {};
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
      programs.fish.shellInit = lib.mkAfter ''
        if test -f "${apiKeyPath}"
          set -gx OPENCODE_API_KEY (string trim -- (cat "${apiKeyPath}"))
        end
      '';

      home = {
        packages = [
          inputs'.llm-agents.packages.opencode
        ];
        shellAliases.nopencode = "nono run --profile opencode --allow-cwd -- opencode";
        file =
          skills
          // commandFiles
          // configs;
      };
    };
  };
}
