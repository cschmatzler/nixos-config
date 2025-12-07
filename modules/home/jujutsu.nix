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
        diff-editor = ["nvim" "-c" "DiffEditor $left $right $output"];
      };
      aliases = {
        tug = ["bookmark" "move" "--from" "closest_bookmark(@-)" "--to" "@-"];
        retrunk = ["rebase" "-d" "trunk()"];
      };
      revset-aliases = {
        "closest_bookmark(to)" = "heads(::to & bookmarks())";
      };
    };
  };
}
