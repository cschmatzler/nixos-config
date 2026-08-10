{
  inputs',
  lib,
  ...
}: let
  theme = (import ../../../_lib/theme.nix).rosePineDawn;
in {
  imports = [
    ./autocmd.nix
    ./mappings.nix
    ./options.nix
    ./plugins/blink-cmp.nix
    ./plugins/code-review.nix
    ./plugins/conform.nix
    ./plugins/diffs.nix
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
    package = inputs'.neovim-nightly-overlay.packages.default.overrideAttrs (old: {
      # TODO: Remove this filter once the nightly source accepts Nixpkgs' CVE-2026-11487 patch.
      patches = lib.filter (patch: !(lib.hasInfix "CVE-2026-11487" (builtins.baseNameOf (toString patch)))) (old.patches or []);
      postInstall =
        (old.postInstall or "")
        + ''
          if [ -e "$out/share/applications/org.neovim.nvim.desktop" ] && [ ! -e "$out/share/applications/nvim.desktop" ]; then
            ln -s org.neovim.nvim.desktop $out/share/applications/nvim.desktop
          fi
        '';
    });
    luaLoader.enable = true;
    colorschemes.${theme.neovim.colorscheme} = {
      enable = true;
      settings = {
        variant = theme.neovim.variant;
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
