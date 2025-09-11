{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Christoph Schmatzler";
        email = "christoph@schmatzler.com";
      };
      diff = {
        tool = "delta";
      };
      ui = {
        default-command = "status";
        diff-formatter = ":git";
        pager = ["delta" "--pager" "less -FRX"];
      };
    };
  };
}
