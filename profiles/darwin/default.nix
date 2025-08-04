{
  config,
  pkgs,
  lib,
  home-manager,
  user,
  ...
}:

{
  imports = [
    ./dock
    ./system.nix
    ./homebrew.nix
    ./secrets.nix
  ];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    users.${user} =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        _module.args = { inherit user; };
        imports = [
          ../base/home-manager/atuin.nix
          ../base/home-manager/bat.nix
          ../base/home-manager/eza.nix
          ../base/home-manager/fish.nix
          ../base/home-manager/ghostty.nix
          ../base/home-manager/git.nix
          ../base/home-manager/jujutsu.nix
          ../base/home-manager/ssh.nix
          ../base/home-manager/starship.nix
          ../base/home-manager/zoxide.nix
          ../base/home-manager/zsh.nix
        ];
        home = {
          packages = pkgs.callPackage ./packages.nix { };
          stateVersion = "23.11";
        };
      };
  };

  local = {
    dock = {
      enable = true;
      username = user;
      entries = [
        { path = "/Applications/Safari.app/"; }
        { path = "/${pkgs.ghostty-bin}/Applications/Ghostty.app/"; }
        { path = "/System/Applications/Notes.app/"; }
        { path = "/System/Applications/Music.app/"; }
        { path = "/System/Applications/System Settings.app/"; }
        {
          path = "${config.users.users.${user}.home}/Downloads";
          section = "others";
          options = "--sort name --view grid --display stack";
        }
      ];
    };
  };
}
