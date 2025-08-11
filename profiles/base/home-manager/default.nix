{
  imports = [
    ./atuin.nix
    ./bat.nix
    ./eza.nix
    ./fish.nix
    ./git.nix
    ./lazygit.nix
    ./neovim
    ./mise.nix
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
}
