{den, ...}: {
  den.aspects.entire = {
    includes = [den.aspects.git];

    homeManager = {
      lib,
      pkgs,
      ...
    }: let
      version = "0.12.2";
      release = builtins.getAttr pkgs.stdenv.hostPlatform.system {
        x86_64-linux = {
          asset = "entire_linux_amd64.tar.gz";
          hash = "sha256-v8XI1bWZ8yh3W4m3NdsCDJY+MHtqMk/DDONx/o+nieg=";
        };
        aarch64-linux = {
          asset = "entire_linux_arm64.tar.gz";
          hash = "sha256-8IobjGNS0/eAdiaNxnsLJz1/YturlLFa7AKOe0JXrQw=";
        };
        x86_64-darwin = {
          asset = "entire_darwin_amd64.tar.gz";
          hash = "sha256-kdH8PNVkKGrDIh8SsdWZCIKylqiPqQJHhuk33ALcb3A=";
        };
        aarch64-darwin = {
          asset = "entire_darwin_arm64.tar.gz";
          hash = "sha256-7I+KMl4PjwsMF3gZBic7XiG8ElsLts+8DGHK2N/Muk8=";
        };
      };
      entire = pkgs.stdenvNoCC.mkDerivation {
        pname = "entire";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/entireio/cli/releases/download/v${version}/${release.asset}";
          inherit (release) hash;
        };

        sourceRoot = ".";
        installPhase = ''
          runHook preInstall

          install -Dm755 entire git-remote-entire -t $out/bin

          runHook postInstall
        '';

        meta = pkgs.entire.meta;
      };
      source = pkgs.fetchFromGitHub {
        owner = "entireio";
        repo = "cli";
        tag = "v${version}";
        hash = "sha256-QIVsDXxQChrgRF6mMNL6gual8tRXBPwDIdx/vY03Wxw=";
      };
      # Match the hook events installed by this pinned Entire release.
      hook = agent: verb: timeout: matcher:
        {
          hooks = [
            ({
                type = "command";
                command = "${entire}/bin/entire hooks ${agent} ${verb} 2>/dev/null || true";
              }
              // lib.optionalAttrs (timeout != null) {inherit timeout;})
          ];
        }
        // lib.optionalAttrs (matcher != null) {inherit matcher;};
      codexHook = verb: timeout: [(hook "codex" verb timeout null)];
      claudeHook = verb: timeout: matcher: [(hook "claude-code" verb timeout matcher)];
      cursorHook = verb: [
        {
          command = "${entire}/bin/entire hooks cursor ${verb} 2>/dev/null || true";
          timeout = 30;
        }
      ];
    in {
      home = {
        packages = [entire];
        sessionVariables.ENTIRE_NO_AUTO_UPDATE = "1";
      };

      programs.codex = {
        settings.features.hooks = true;
        hooks = {
          SessionStart = codexHook "session-start" 30;
          SessionEnd = codexHook "session-end" 3;
          UserPromptSubmit = codexHook "user-prompt-submit" 30;
          Stop = codexHook "stop" 30;
          PostToolUse = codexHook "post-tool-use" 30;
          SubagentStart = codexHook "subagent-start" 30;
          SubagentStop = codexHook "subagent-stop" 30;
        };
      };
      programs.claude-code.settings.hooks = {
        SessionStart = claudeHook "session-start" 30 null;
        SessionEnd = claudeHook "session-end" null null;
        UserPromptSubmit = claudeHook "user-prompt-submit" 30 null;
        Stop = claudeHook "stop" 120 null;
        StopFailure = claudeHook "stop-failure" 120 null;
        PreToolUse = claudeHook "pre-task" 30 "Agent";
        PostToolUse = claudeHook "post-task" 120 "Agent|Skill";
        SubagentStart = claudeHook "subagent-start" 30 "workflow-subagent";
        SubagentStop = claudeHook "subagent-stop" 120 null;
      };
      programs.cursor-agent.hooks = {
        sessionStart = cursorHook "session-start";
        sessionEnd = cursorHook "session-end";
        beforeSubmitPrompt = cursorHook "before-submit-prompt";
        stop = cursorHook "stop";
        preCompact = cursorHook "pre-compact";
        subagentStart = cursorHook "subagent-start";
        subagentStop = cursorHook "subagent-stop";
      };
      xdg.configFile."opencode/plugins/entire.ts".source = "${source}/cmd/entire/cli/agent/opencode/entire_plugin.ts";
    };
  };
}
