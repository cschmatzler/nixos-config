{den, ...}: {
  den.aspects.cursor-agent = {
    includes = [den.aspects.agents];

    homeManager = {
      config,
      inputs',
      lib,
      ...
    }: {
      options.programs.cursor-agent.hooks = lib.mkOption {
        type = with lib.types; attrsOf (listOf attrs);
        default = {};
        description = "Cursor lifecycle hooks, merged across agent integrations.";
      };
      config = {
        home.packages = [inputs'.llm-agents.packages.cursor-agent];
        home.file.".cursor/hooks.json".text = builtins.toJSON {
          version = 1;
          hooks = config.programs.cursor-agent.hooks;
        };
      };
    };
  };
}
