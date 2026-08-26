inputs: let
  mattpocockSkillPaths =
    (builtins.fromJSON (builtins.readFile (inputs.mattpocock-skills + "/.claude-plugin/plugin.json"))).skills;
  mattpocockSkills = builtins.listToAttrs (map (skillPath: {
      name = builtins.baseNameOf skillPath;
      value = inputs.mattpocock-skills + "/${skillPath}";
    })
    mattpocockSkillPaths);
in
  mattpocockSkills
  // {
    bro = inputs.dmmulroy-skills + "/bro";
    effect-service-design = inputs.dmmulroy-skills + "/effect-service-design";
  }
