{
  imports = [
    ./atuin.nix
    ./bat.nix
    ./lazygit.nix
    ./eza.nix
    ./fish.nix
    ./git.nix
    ./neovim
    ./ssh.nix
    ./starship.nix
    ./zellij.nix
    ./zoxide.nix
    ./zsh.nix
  ];

  programs.home-manager.enable = true;
}
