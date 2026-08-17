{den, ...}: {
  den.aspects.plannotator = {
    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      commandPayloads = import ./_plannotator/commands.nix;
      jsonFormat = pkgs.formats.json {};
      local = import ../../_lib/local.nix;
      bunForPlannotator = pkgs.bun.overrideAttrs {
        version = "1.3.11";
        src = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.11/bun-darwin-aarch64.zip";
          hash = "sha256-b1o0Z+2crsR5W/eM1HZQfZ+HDH1XuGyUX8szgSZ3L/w=";
        };
      };
      plannotatorPackage = inputs'.llm-agents.packages.plannotator;
      plannotator =
        if pkgs.stdenv.hostPlatform.isDarwin
        then
          plannotatorPackage.overrideAttrs (oldAttrs: {
            nativeBuildInputs =
              [pkgs.darwin.autoSignDarwinBinariesHook]
              ++ map (input:
                if (input.pname or null) == "bun"
                then bunForPlannotator
                else input)
              oldAttrs.nativeBuildInputs;
          })
        else plannotatorPackage;
      plannotatorConfig = {
        diffOptions = {
          defaultDiffType = "since-base";
          diffStyle = "split";
          diffIndicators = "bars";
          lineDiffType = "word-alt";
          fontFamily = "";
        };
        displayName = local.user.fullName;
        prompts.review.runtimes.pi.denied = ''
          The comments above are review directions written by the user. Treat them as intentional and correct by default, and address each one. Use the code to determine the right implementation. If a direction appears incorrect or harmful, raise the specific concern instead of following it blindly. Do not treat the comments as automated or unverified feedback, and do not require a verdict for each one.

          Review only the submitted comments. Do not independently review the rest of the diff or search for issues that were not submitted.
        '';
      };
    in {
      den.aspects.pi.packageDeclarations = [
        "npm:@plannotator/pi-extension"
        "${./_plannotator/hide-progress.ts}"
      ];

      programs.claude-code = {
        commands = {
          plannotator-annotate = commandPayloads.annotate;
          plannotator-last = commandPayloads.last;
          plannotator-review = commandPayloads.review;
        };
        settings.hooks = {
          PreToolUse = [
            {
              matcher = "EnterPlanMode";
              hooks = [
                {
                  type = "command";
                  command = "${plannotator}/bin/plannotator improve-context";
                  timeout = 5;
                }
              ];
            }
          ];
          PermissionRequest = [
            {
              matcher = "ExitPlanMode";
              hooks = [
                {
                  type = "command";
                  command = "${plannotator}/bin/plannotator";
                  timeout = 345600;
                }
              ];
            }
          ];
        };
      };

      home = {
        file.".plannotator/config.json".source = jsonFormat.generate "plannotator-config.json" plannotatorConfig;
        sessionVariables = {
          PLANNOTATOR_PORT = "20000";
          PLANNOTATOR_REMOTE = "1";
        };
        packages = [plannotator];
      };
    };

    nixos = {
      lib,
      pkgs,
      ...
    }: {
      systemd.services.plannotator-tailscale = (import ../../_lib/tailscale-serve-exposure.nix {inherit lib;}) {
        inherit pkgs;
        workload = "Plannotator Pi plugin";
        identity = "svc:plannotator";
        port = 20000;
      };
    };
  };
}
