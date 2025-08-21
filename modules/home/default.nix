{
  pkgs,
  constants,
  ...
}: {
  imports = [
    ./atuin.nix
    ./bash.nix
    ./bat.nix
    ./direnv.nix
    ./eza.nix
    ./fish.nix
    ./fzf.nix
    ./git.nix
    ./lazygit.nix
    ./mise.nix
    ./neovim
    ./opencode.nix
    ./ripgrep.nix
    ./ssh.nix
    ./starship.nix
    ./zellij.nix
    ./zoxide.nix
    ./zsh.nix
  ];

  programs.home-manager.enable = true;

  home = {
    packages = pkgs.callPackage ../packages.nix {};
    stateVersion = constants.stateVersions.homeManager;
  };
}
