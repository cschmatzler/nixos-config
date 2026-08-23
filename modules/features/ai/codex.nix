{den, ...}: {
  den.aspects.codex = {
    includes = [den.aspects.javascript];

    os = {pkgs, ...}: {
      environment.etc."codex/config.toml".source = (pkgs.formats.toml {}).generate "codex-system-config" {
        mcp_servers = {
          opensrc = {
            command = "npx";
            args = [
              "-y"
              "opensrc-mcp"
            ];
          };
          executor.url = "https://executor.manticore-hippocampus.ts.net/mcp/toolkits/general";
        };
      };
    };

    homeManager = {inputs', ...}: {
      programs.codex = {
        enable = true;
        package = inputs'.llm-agents.packages.codex;
        skills = {
          coding-standards = ./_skills/coding-standards;
          effect = ./_skills/effect;
          life-os = ./_skills/life-os;
          wrdn-authz = ./_skills/wrdn-authz;
          wrdn-code-execution = ./_skills/wrdn-code-execution;
          wrdn-data-exfil = ./_skills/wrdn-data-exfil;
          wrdn-gha-workflows = ./_skills/wrdn-gha-workflows;
          wrdn-pii = ./_skills/wrdn-pii;
        };
      };
    };
  };
}
