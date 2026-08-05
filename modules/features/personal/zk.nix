_: {
  den.aspects.zk.homeManager = _: {
    programs.zk = {
      enable = true;
      settings = {};
    };
    home.sessionVariables = {
      ZK_NOTEBOOK_DIR = "$HOME/Projects/Personal/Zettelkasten";
    };
  };
}
