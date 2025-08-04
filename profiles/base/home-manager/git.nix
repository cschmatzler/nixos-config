{
  ...
}:

let
  name = "Christoph Schmatzler";
in
{
  programs.git = {
    enable = true;
    ignores = [ "*.swp" ];
    userName = name;
    lfs = {
      enable = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      # commit.gpgsign = true;
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };
}
