{
  imports = [
    ./autocmd.nix
    ./mappings.nix
    ./options.nix
    ./plugins/conform.nix
    ./plugins/blink-cmp.nix
    ./plugins/grug-far.nix
    ./plugins/oil.nix
    ./plugins/lazygit.nix
    ./plugins/lsp.nix
    ./plugins/mini.nix
    ./plugins/treesitter.nix
  ];

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
