_: {
  den.aspects.pi-browser.homeManager = {pkgs, ...}: {
    home.packages = [(import ./_pi-browser/package.nix {inherit pkgs;})];
    home.file.".agents/skills/pi-browser".source = ./_pi-browser/skill;
  };
}
