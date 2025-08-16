{
  pkgs,
  constants,
  ...
}: {
  imports = [
    ./fish.nix
    ./starship.nix
    ./zsh.nix
    ./atuin.nix
    ./bat.nix
    ./eza.nix
    ./git.nix
    ./lazygit.nix
    ./mise.nix
    ./ssh.nix
    ./zellij.nix
    ./zoxide.nix
    ./neovim
  ];

  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home = {
    packages = pkgs.callPackage ../packages.nix {};
    stateVersion = constants.stateVersions.homeManager;
    shellAliases = {
      v = "nvim";
      lg = "lazygit";
    };
  };
}
