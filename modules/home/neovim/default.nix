{
  imports = [
    ./autocmd.nix
    ./mappings.nix
    ./options.nix
    ./plugins/blink-cmp.nix
    ./plugins/conform.nix
    ./plugins/grug-far.nix
    ./plugins/lsp.nix
    ./plugins/mini.nix
    ./plugins/supermaven.nix
    ./plugins/oil.nix
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
    extraConfigLua = ''
      vim.ui.select = MiniPick.ui_select
    '';
  };

  home.shellAliases = {
    v = "nvim";
  };
}
