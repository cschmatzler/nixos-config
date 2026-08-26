{
  den,
  inputs,
  ...
}: let
  externalSkills = import ./_shared/external-skills.nix inputs;
in {
  den.aspects.claude-code = {
    includes = [den.aspects.javascript];

    homeManager = {inputs', ...}: let
      commandPayloads = import ./_shared/commands.nix;
    in {
      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        commands = {
          rmslop = commandPayloads.rmslop;
          albanian-lesson = commandPayloads."albanian-lesson";
          inbox-triage = commandPayloads."inbox-triage";
        };
        skills =
          {
            coding-standards = ./_skills/coding-standards;
            effect = ./_skills/effect;
            life-os = ./_skills/life-os;
            wrdn-authz = ./_skills/wrdn-authz;
            wrdn-code-execution = ./_skills/wrdn-code-execution;
            wrdn-data-exfil = ./_skills/wrdn-data-exfil;
            wrdn-gha-workflows = ./_skills/wrdn-gha-workflows;
            wrdn-pii = ./_skills/wrdn-pii;
          }
          // externalSkills;
        mcpServers = {
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

      home = {
        file.".claude/tmp/.keep".text = "";
        sessionVariables.DISABLE_AUTOUPDATER = "1";
      };
    };
  };
}
