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
      url = "https://executor.sh/mcp/toolkits/general";
    };
  };

  sharedMembership = {
    commands = [
      "rmslop"
      "albanian-lesson"
      "inbox-triage"
    ];
    skills = [
      "coding-standards"
      "effect"
      "wrdn-authz"
      "wrdn-code-execution"
      "wrdn-data-exfil"
      "wrdn-gha-workflows"
      "wrdn-pii"
    ];
    mcp = [
      "opensrc"
      "executor"
    ];
  };

  adapterMembership = {
    pi = sharedMembership;
    "claude-code" =
      sharedMembership
      // {
        commands =
          sharedMembership.commands
          ++ [
            "plannotator-annotate"
            "plannotator-last"
            "plannotator-review"
          ];
      };
  };

  select = adapter: kind: entries: names: let
    unknownNames = builtins.filter (name: ! builtins.hasAttr name entries) names;
  in
    assert lib.assertMsg (unknownNames == []) "AI Tool Inventory Adapter ${adapter} selects unknown ${kind}: ${lib.concatStringsSep ", " unknownNames}";
    assert lib.assertMsg (lib.length names == lib.length (lib.unique names)) "AI Tool Inventory Adapter ${adapter} selects duplicate ${kind}";
      lib.genAttrs names (name: entries.${name});

  validateMcp = name: entry:
    assert lib.assertMsg (lib.elem entry.kind ["local" "remote"]) "AI Tool Inventory MCP entry ${name} has an unsupported kind";
    assert lib.assertMsg (entry.kind != "local" || entry.command != []) "AI Tool Inventory local MCP entry ${name} must have a command"; entry;
in {
  forAdapter = adapter:
    assert lib.assertMsg (builtins.hasAttr adapter adapterMembership) "Unknown AI Tool Inventory Adapter: ${adapter}"; let
      membership = adapterMembership.${adapter};
    in {
      commands = select adapter "commands" commands membership.commands;
      skills = select adapter "skills" skills membership.skills;
      mcp = lib.mapAttrs validateMcp (select adapter "MCP entries" mcp membership.mcp);
    };
}
