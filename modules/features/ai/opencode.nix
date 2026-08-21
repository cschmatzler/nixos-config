{den, ...}: {
  den.aspects.opencode = {
    includes = [den.aspects.javascript];

    homeManager = {inputs', ...}: {
      programs.opencode = {
        enable = true;
        package = inputs'.llm-agents.packages.opencode;
        settings.mcp = {
          opensrc = {
            type = "local";
            command = [
              "npx"
              "-y"
              "opensrc-mcp"
            ];
            enabled = true;
          };
          executor = {
            type = "remote";
            url = "https://executor.manticore-hippocampus.ts.net/mcp/toolkits/general";
            enabled = true;
          };
        };
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
