{...}: let
  local = import ../../_lib/local.nix;

  secret = key: {
    sopsFile = ../../../secrets/langfuse;
    format = "yaml";
    inherit key;
  };

  rendered = content: {
    inherit content;
    owner = local.user.name;
  };
in {
  den.aspects.langfuse = {
    # Host includes install the secrets. Workstation users wire the agents.
    os = {config, ...}: {
      sops.secrets = {
        langfuse-public-key = secret "public-key";
        langfuse-secret-key = secret "secret-key";
        langfuse-base-url = secret "base-url";
        langfuse-environment = secret "environment";
      };

      sops.templates = {
        "codex-langfuse.json" = rendered (builtins.toJSON {
          enabled = true;
          public_key = config.sops.placeholder.langfuse-public-key;
          secret_key = config.sops.placeholder.langfuse-secret-key;
          base_url = config.sops.placeholder.langfuse-base-url;
          environment = config.sops.placeholder.langfuse-environment;
        });
        "cursor-langfuse.json" = rendered (builtins.toJSON {
          enabled = true;
          publicKey = config.sops.placeholder.langfuse-public-key;
          secretKey = config.sops.placeholder.langfuse-secret-key;
          baseUrl = config.sops.placeholder.langfuse-base-url;
          environment = config.sops.placeholder.langfuse-environment;
        });
        "claude-langfuse.env" = rendered ''
          LANGFUSE_PUBLIC_KEY='${config.sops.placeholder.langfuse-public-key}'
          LANGFUSE_SECRET_KEY='${config.sops.placeholder.langfuse-secret-key}'
          LANGFUSE_BASE_URL='${config.sops.placeholder.langfuse-base-url}'
          LANGFUSE_TRACING_ENVIRONMENT='${config.sops.placeholder.langfuse-environment}'
        '';
      };
    };

    homeManager = {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }: let
      node = "${pkgs.nodejs_26}/bin/node";

      codexPlugin =
        pkgs.runCommand "langfuse-codex-plugin" {
          src = pkgs.fetchurl {
            url = "https://registry.npmjs.org/@langfuse/codex-observability-plugin/-/codex-observability-plugin-0.4.2.tgz";
            hash = "sha256-Z86tEzqfqWpx+SfBMx6tGByUl59dfruq9LzvYaMMW6I=";
          };
        } ''
          tar -xzf "$src"
          mv package "$out"
        '';

      cursorPlugin = pkgs.fetchFromGitHub {
        owner = "langfuse";
        repo = "cursor-observability-plugin";
        rev = "a65bd2b752f785c2cc76911b82011d958b4d0411";
        hash = "sha256-MmDI+mOzuPBjhxcjLjyAgHj+5vmisUei7n4XBYIv1ZE=";
      };

      claudePlugin = pkgs.fetchFromGitHub {
        owner = "langfuse";
        repo = "Claude-Observability-Plugin";
        rev = "b5b7cc364996467e856dc17575b5674f4799ad87";
        hash = "sha256-CtJoFjDYahYNTl/6uBMly1OiRdIY+QigENA8M6pd9O0=";
      };

      claudeHook = pkgs.writeShellScript "claude-langfuse-hook" ''
        set -eu
        envfile=${lib.escapeShellArg osConfig.sops.templates."claude-langfuse.env".path}
        if [[ ! -r $envfile ]]; then
          exit 0
        fi
        set -a
        # shellcheck disable=SC1090
        source "$envfile"
        set +a
        exec ${pkgs.uv}/bin/uv run --quiet --script ${lib.escapeShellArg "${claudePlugin}/hooks/langfuse_hook.py"}
      '';

      cursorCommand = "${node} ${cursorPlugin}/dist/index.mjs";
      cursorHook = timeout: [
        {
          command = cursorCommand;
          inherit timeout;
        }
      ];
    in {
      programs.codex = {
        settings.features.hooks = true;
        hooks.Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "${node} ${codexPlugin}/dist/index.mjs";
                timeout = 30;
                statusMessage = "Uploading Codex trace to Langfuse";
              }
            ];
          }
        ];
      };

      programs.claude-code.settings.hooks = {
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = claudeHook;
              }
            ];
          }
        ];
        SessionEnd = [
          {
            hooks = [
              {
                type = "command";
                command = claudeHook;
              }
            ];
          }
        ];
      };

      programs.cursor-agent.hooks = {
        sessionStart = cursorHook 10;
        sessionEnd = cursorHook 60;
        beforeSubmitPrompt = cursorHook 60;
        preToolUse = cursorHook 10;
        postToolUse = cursorHook 10;
        postToolUseFailure = cursorHook 10;
        subagentStart = cursorHook 10;
        subagentStop = cursorHook 10;
        beforeShellExecution = cursorHook 10;
        afterShellExecution = cursorHook 10;
        beforeMCPExecution = cursorHook 10;
        afterMCPExecution = cursorHook 10;
        beforeReadFile = cursorHook 10;
        afterFileEdit = cursorHook 10;
        afterAgentResponse = cursorHook 10;
        afterAgentThought = cursorHook 10;
        preCompact = cursorHook 10;
        stop = cursorHook 60;
      };

      home.file = {
        ".codex/langfuse.json".source = config.lib.file.mkOutOfStoreSymlink osConfig.sops.templates."codex-langfuse.json".path;
        ".cursor/langfuse.json".source = config.lib.file.mkOutOfStoreSymlink osConfig.sops.templates."cursor-langfuse.json".path;
      };
    };
  };
}
