inputs: let
  skillPaths =
    (builtins.fromJSON (builtins.readFile (inputs.mattpocock-skills + "/.claude-plugin/plugin.json"))).skills;
in
  builtins.listToAttrs (map (skillPath: {
      name = builtins.baseNameOf skillPath;
      value = inputs.mattpocock-skills + "/${skillPath}";
    })
    skillPaths)
