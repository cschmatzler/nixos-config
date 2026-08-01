{
  commands = import ../_ai/commands.nix;

  skillNames = [
    "coding-standards"
    "effect"
    "herdr"
    "wrdn-authz"
    "wrdn-code-execution"
    "wrdn-data-exfil"
    "wrdn-gha-workflows"
    "wrdn-pii"
  ];

  plannotatorCommandNames = [
    "plannotator-annotate"
    "plannotator-last"
    "plannotator-review"
  ];
}
