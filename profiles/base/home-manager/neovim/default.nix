{
  imports = [
    ./autocmd.nix
    ./mappings.nix
    ./options.nix
    ./plugins/conform.nix
    ./plugins/lazygit.nix
    ./plugins/lsp.nix
    ./plugins/mini.nix
    ./plugins/oil.nix
    ./plugins/treesitter.nix
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

  };
}
