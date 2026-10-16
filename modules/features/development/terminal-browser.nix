_: {
  den.aspects.terminal-browser.homeManager = {pkgs, ...}: let
    browser = import ./_terminal-browser/package.nix {inherit pkgs;};
  in {
    home.packages = [browser];
    home.file.".agents/skills/terminal-browser".source = browser.skillPath;
    programs.herdr.extraPlugins.terminal-browser = ./_terminal-browser/herdr-plugin;
  };
}
