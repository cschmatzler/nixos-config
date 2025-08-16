{
  pkgs,
  constants,
  ...
}: {
  imports = [
    ./atuin.nix
    ./bat.nix
    ./eza.nix
    ./fish.nix
    ./git.nix
    ./lazygit.nix
    ./mise.nix
    ./neovim
    ./ripgrep.nix
    ./ssh.nix
    ./starship.nix
    ./zellij.nix
    ./zoxide.nix
    ./zsh.nix
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
