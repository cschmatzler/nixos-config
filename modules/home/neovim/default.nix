{
  imports = [
    ./autocmd.nix
    ./mappings.nix
    ./options.nix
    ./plugins/blink-cmp.nix
    ./plugins/conform.nix
    ./plugins/copilot.nix
    ./plugins/grug-far.nix
    ./plugins/harpoon.nix
    ./plugins/hunk.nix
    ./plugins/lsp.nix
    ./plugins/mini.nix
    ./plugins/oil.nix
    ./plugins/toggleterm.nix
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
