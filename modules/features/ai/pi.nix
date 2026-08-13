{
  den,
  inputs,
  ...
}: let
  local = import ../../_lib/local.nix;
  secretLib = import ../../_lib/secrets.nix {};
in {
  den.aspects.pi = {
    includes = [den.aspects.javascript];

    os.sops.secrets.supermemory-api-key = secretLib.mkUserBinarySecret {
      name = "supermemory-api-key";
      sopsFile = ../../../secrets/supermemory-api-key;
    };

    homeManager = {
      config,
      inputs',
      lib,
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      nonoPackage = inputs'.llm-agents.packages.nono;
      piPackage = inputs'.llm-agents.packages.pi;
      piProfile = "${config.xdg.configHome}/nono/profiles/pi.json";
      piCommand = pkgs.writeShellScriptBin "pi" ''
        exec ${nonoPackage}/bin/nono run --allow-cwd --profile ${lib.escapeShellArg piProfile} -- ${piPackage}/bin/pi "$@"
      '';
      aiTools = (import ./_shared/inventory.nix {inherit lib local;}).forAdapter "pi";
      mcpServers =
        lib.mapAttrs (
          name: endpoint:
            if endpoint.kind == "local"
            then {
              type = "local";
              inherit (endpoint) command;
              enabled = true;
            }
            else if endpoint.kind == "remote"
            then {
              type = "remote";
              inherit (endpoint) url;
              enabled = true;
            }
            else throw "Unsupported Pi MCP kind for ${name}: ${endpoint.kind}"
        )
        aiTools.mcp;
      promptFiles =
        lib.mapAttrs' (
          name: command:
            lib.nameValuePair ".pi/agent/prompts/${name}.md" {inherit (command) text;}
        )
        aiTools.commands;
      skillFiles =
        lib.mapAttrs' (
          name: skill:
            lib.nameValuePair ".pi/agent/skills/${name}" {
              inherit (skill) source;
              recursive = true;
            }
        )
        aiTools.skills;
      plannotatorConfig = {
        diffOptions = {
          defaultDiffType = "since-base";
          diffStyle = "split";
          diffIndicators = "bars";
          lineDiffType = "word-alt";
          fontFamily = "";
        };
        displayName = "Christoph Schmatzler";
        prompts.review.runtimes.pi.denied = ''
          The comments above are review directions written by the user. Treat them as intentional and correct by default, and address each one. Use the code to determine the right implementation. If a direction appears incorrect or harmful, raise the specific concern instead of following it blindly. Do not treat the comments as automated or unverified feedback, and do not require a verdict for each one.

          Review only the submitted comments. Do not independently review the rest of the diff or search for issues that were not submitted.
        '';
      };
      settings = {
        theme = "light";
        quietStartup = true;
        hideThinkingBlock = true;
        showCacheMissNotices = true;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-sol";
        defaultThinkingLevel = "high";
        enableInstallTelemetry = false;
        packages = [
          (toString (inputs.nono-packs + "/pi"))
          "git:github.com/dmmulroy/pi-mcp@761c81dc5d4e0745f4ae77dcacb1be5517b18101"
          "npm:@awesamarth/pi-supermemory"
          "npm:@ogulcancelik/pi-herdr"
          "npm:@plannotator/pi-extension"
          "npm:@tunnckocore/pi-gpt-fast-mode"
          "npm:pi-cache-optimizer"
          "npm:mattpocock-skills-unofficial-plugin"
          "npm:pi-claude-auth"
        ];
        prompts = ["./prompts"];
        skills = ["./skills"];
      };
    in {
      home = {
        packages = [piCommand];

        file =
          {
            ".plannotator/config.json".source = jsonFormat.generate "plannotator-config.json" plannotatorConfig;

            ".pi/tmp/.keep".text = "";
            ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
            ".pi/agent/mcp.json".source = jsonFormat.generate "pi-mcp.json" {
              mcp = {
                toolMode = "direct";
                startup = "eager";
                servers = mcpServers;
              };
            };

            ".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
            ".pi/agent/extensions/answer.ts".source = ./_pi/extensions/answer.ts;
            ".pi/agent/extensions/compact-footer.ts".source = ./_pi/extensions/compact-footer.ts;
            ".pi/agent/extensions/executor-resume-approval.ts".source = ./_pi/extensions/executor-resume-approval.ts;
            ".pi/agent/extensions/git-interceptor.ts".source = ./_pi/extensions/git-interceptor.ts;
            ".pi/agent/extensions/todos.ts".source = ./_pi/extensions/todos.ts;
            ".pi/agent/extensions/whimsical.ts".source = ./_pi/extensions/whimsical.ts;
          }
          // promptFiles
          // skillFiles;
      };
    };
  };
}
