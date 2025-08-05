{pkgs, ...}: {
  imports = [
    ./autocmd.nix
    ./plugins/conform.nix
    ./plugins/mini.nix
    ./plugins/oil.nix
    ./plugins/treesitter.nix
    ./plugins/which-key.nix
  ];

  home.shellAliases.v = "nvim";

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    luaLoader.enable = true;

    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "latte";
      };
    };

    clipboard.register = "unnamedplus";
  };
}
