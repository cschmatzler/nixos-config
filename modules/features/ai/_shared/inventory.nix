{
  lib,
  local,
}: let
  commandPayloads = import ./commands.nix;

  commands = {
    rmslop.text = commandPayloads.rmslop;
    "albanian-lesson".text = commandPayloads."albanian-lesson";
    "inbox-triage".text = commandPayloads."inbox-triage";
    "plannotator-annotate".text = commandPayloads."plannotator-annotate";
    "plannotator-last".text = commandPayloads."plannotator-last";
    "plannotator-review".text = commandPayloads."plannotator-review";
  };

  skills = {
    "coding-standards".source = ../_skills/coding-standards;
    effect.source = ../_skills/effect;
    "wrdn-authz".source = ../_skills/wrdn-authz;
    "wrdn-code-execution".source = ../_skills/wrdn-code-execution;
    "wrdn-data-exfil".source = ../_skills/wrdn-data-exfil;
    "wrdn-gha-workflows".source = ../_skills/wrdn-gha-workflows;
    "wrdn-pii".source = ../_skills/wrdn-pii;
  };

  mcp = {
    opensrc = {
      kind = "local";
      command = [
        "npx"
        "-y"
        "opensrc-mcp"
      ];
    };
    executor = {
      kind = "remote";
      url = "https://executor.manticore-hippocampus.ts.net/mcp/toolkits/general";
    };
  };
in {
  pi = {
    commands =
      lib.getAttrs [
        "rmslop"
        "albanian-lesson"
        "inbox-triage"
      ]
      commands;
    skills =
      lib.getAttrs [
        "coding-standards"
        "effect"
        "wrdn-authz"
        "wrdn-code-execution"
        "wrdn-data-exfil"
        "wrdn-gha-workflows"
        "wrdn-pii"
      ]
      skills;
    mcp =
      lib.getAttrs [
        "opensrc"
        "executor"
      ]
      mcp;
  };

  "claude-code" = {
    commands =
      lib.getAttrs [
        "rmslop"
        "albanian-lesson"
        "inbox-triage"
        "plannotator-annotate"
        "plannotator-last"
        "plannotator-review"
      ]
      commands;
    skills =
      lib.getAttrs [
        "coding-standards"
        "effect"
        "wrdn-authz"
        "wrdn-code-execution"
        "wrdn-data-exfil"
        "wrdn-gha-workflows"
        "wrdn-pii"
      ]
      skills;
    mcp =
      lib.getAttrs [
        "opensrc"
        "executor"
      ]
      mcp;
  };
}
