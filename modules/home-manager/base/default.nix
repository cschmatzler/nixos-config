{
  imports = [
    ./shell/aliases.nix
    ./shell/fish.nix
    ./shell/starship.nix
    ./shell/zsh.nix
    ./tools/atuin.nix
    ./tools/bat.nix
    ./tools/eza.nix
    ./tools/git.nix
    ./tools/lazygit.nix
    ./tools/mise.nix
    ./tools/ssh.nix
    ./tools/zellij.nix
    ./tools/zoxide.nix
    ./editors/neovim
  ];

  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}