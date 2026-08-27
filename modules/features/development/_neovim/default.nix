{...}:
with (import ../../../_lib/theme.nix).rosePineDawn; {
  imports = [
    ./autocmd.nix
    ./mappings.nix
    ./options.nix
    ./plugins/blink-cmp.nix
    ./plugins/code-review.nix
    ./plugins/codediff.nix
    ./plugins/conform.nix
    ./plugins/flash.nix
    ./plugins/grug-far.nix
    ./plugins/hardtime.nix
    ./plugins/harpoon.nix
    ./plugins/hunk.nix
    ./plugins/lsp.nix
    ./plugins/lualine.nix
    ./plugins/mini.nix
    ./plugins/neogit.nix
    ./plugins/noice.nix
    ./plugins/oil.nix
    ./plugins/render-markdown.nix
    ./plugins/snacks.nix
    ./plugins/toggleterm.nix
    ./plugins/treesitter.nix
    ./plugins/which-key.nix
    ./plugins/zk.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    luaLoader.enable = true;
    colorschemes.${neovim.colorscheme} = {
      enable = true;
      settings = {
        variant = neovim.variant;
        styles = {
          italic = false;
          transparency = false;
        };
        highlight_groups = {
          DiffAdd = {
            bg = "leaf";
            blend = 12;
          };
          DiffChange = {
            bg = "rose";
            blend = 12;
          };
          DiffDelete = {
            bg = "love";
            blend = 12;
          };
          DiffText = {
            bg = "rose";
            blend = 30;
            bold = true;
          };
          CodeDiffCharInsertTheme = {
            bg = "leaf";
            blend = 30;
            bold = true;
          };
          CodeDiffCharDeleteTheme = {
            bg = "love";
            blend = 30;
            bold = true;
          };
          Visual = {
            fg = "text";
            bg = "iris";
            blend = 45;
            bold = true;
          };
          VisualNOS = {
            link = "Visual";
          };
        };
      };
    };
  };

  home.shellAliases = {
    v = "nvim";
  };
}
