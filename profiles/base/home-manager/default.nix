{
  imports = [
    ./atuin.nix
    ./bat.nix
    ./eza.nix
    ./fish.nix
    ./git.nix
    ./jujutsu.nix
    ./neovim
    ./ssh.nix
    ./starship.nix
    ./zellij.nix
    ./zoxide.nix
    ./zsh.nix
  ];

  programs.home-manager.enable = true;
}
