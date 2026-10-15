{inputs, ...}: {
  flake-file.inputs = {
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.flake-parts.follows = "flake-parts";
    };
    code-review-nvim = {
      url = "github:choplin/code-review.nvim";
      flake = false;
    };
  };

  den.aspects.neovim.homeManager = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      inputs.nixvim.homeModules.nixvim
      ./_neovim/mappings.nix
      ./_neovim/plugins.nix
    ];

    home.sessionVariables.MANPAGER = "nvim +Man!";
    home.shellAliases.v = "nvim";

    programs.zsh.initContent = ''
      fvim() {
        local file
        file="$(${pkgs.fd}/bin/fd -H -t f | ${pkgs.fzf}/bin/fzf --header "Open File in Vim" --preview "${pkgs.coreutils}/bin/cat {}" --query "$*")" || return
        [[ -n "$file" ]] && ${config.programs.nixvim.build.package}/bin/nvim -- "$file"
      }
    '';

    programs.nixvim = {
      enable = true;
      defaultEditor = true;
      package = pkgs.neovim-unwrapped.overrideAttrs {
        version = "0.12.6";
        src = pkgs.fetchFromGitHub {
          owner = "neovim";
          repo = "neovim";
          tag = "v0.12.6";
          hash = "sha256-lK1gbJyESMN3C/i8cyPFzzlJDYZHzEXugGhCwPVEbNk=";
        };
      };
      luaLoader.enable = true;
      version.enableNixpkgsReleaseCheck = false;

      colorschemes.rose-pine = {
        enable = true;
        settings = {
          variant = "dawn";
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
            VisualNOS.link = "Visual";
          };
        };
      };

      globals = {
        clipboard = "osc52";
        mapleader = " ";
        maplocalleader = " ";
      };

      opts = {
        winborder = "single";
        expandtab = true;
        fillchars.diff = " ";
        softtabstop = 2;
        tabstop = 2;
        ignorecase = true;
        list = false;
        mouse = "";
        relativenumber = true;
        scrolloff = 8;
        shiftwidth = 2;
        smartcase = true;
        undofile = true;
      };

      autoGroups.Christoph = {};
      autoCmd = [
        {
          event = ["VimEnter" "ColorScheme"];
          group = "Christoph";
          pattern = "*";
          callback.__raw = ''
            function()
              local p = require("rose-pine.palette")
              vim.api.nvim_set_hl(0, "NormalFloat", { bg = p.base })
              vim.api.nvim_set_hl(0, "FloatTitle", { fg = p.foam, bg = p.base, bold = true })
              vim.api.nvim_set_hl(0, "Pmenu", { fg = p.subtle, bg = p.base })
              vim.api.nvim_set_hl(0, "PmenuExtra", { fg = p.muted, bg = p.base })
              vim.api.nvim_set_hl(0, "PmenuKind", { fg = p.foam, bg = p.base })
              vim.api.nvim_set_hl(0, "PmenuSbar", { bg = p.base })
              vim.api.nvim_set_hl(0, "SnacksPickerBorder", { fg = p.highlight_high, bg = p.base })
              vim.api.nvim_set_hl(0, "SnacksPickerTitle", { fg = p.foam, bg = p.base, bold = true })
              vim.api.nvim_set_hl(0, "SnacksPickerPrompt", { fg = p.iris, bg = p.base, bold = true })
              vim.api.nvim_set_hl(0, "SnacksInputBorder", { fg = p.highlight_high, bg = p.base })
              vim.api.nvim_set_hl(0, "SnacksInputTitle", { fg = p.foam, bg = p.base, bold = true })
              vim.api.nvim_set_hl(0, "SnacksIndent", { fg = p.highlight_med })
              vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = p.iris })
              vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = p.base })
              vim.api.nvim_set_hl(0, "WhichKeyBorder", { fg = p.highlight_high, bg = p.base })
              vim.api.nvim_set_hl(0, "WhichKeyTitle", { fg = p.foam, bg = p.base, bold = true })
              vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = p.iris, bg = p.base })
              vim.api.nvim_set_hl(0, "NoiceCmdlineIcon", { fg = p.foam, bg = p.base })
            end
          '';
        }
        {
          event = "BufWritePre";
          group = "Christoph";
          pattern = "*";
          command = "%s/\\s\\+$//e";
        }
        {
          event = ["BufReadPost" "FileReadPost"];
          group = "Christoph";
          pattern = "*";
          command = "normal zR";
        }
        {
          event = "User";
          group = "Christoph";
          pattern = "SnacksDashboardOpened";
          callback.__raw = ''
            function()
              vim.b.minitrailspace_disable = true
              pcall(function()
                require("mini.trailspace").unhighlight()
              end)
            end
          '';
        }
        {
          event = "FileType";
          group = "Christoph";
          pattern = "elixir,eelixir,heex";
          command = "setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2";
        }
      ];

      extraPlugins = [
        pkgs.vimPlugins.codediff-nvim
        (pkgs.vimUtils.buildVimPlugin {
          pname = "code-review-nvim";
          version = "unstable";
          src = inputs.code-review-nvim;
          doCheck = false;
        })
      ];
      extraConfigLua = ''
        -- The optional watcher cannot install into the read-only Nix store.
        -- Use CodeDiff's polling fallback unless a watcher is already available.
        vim.env.CODEDIFF_WATCHER_NO_AUTO_INSTALL = "1"
        require("codediff").setup({
          highlights = {
            line_insert = "DiffAdd",
            line_delete = "DiffDelete",
            char_insert = "CodeDiffCharInsertTheme",
            char_delete = "CodeDiffCharDeleteTheme",
          },
          diff = {
            layout = "inline",
            filler_text = "",
            compact = true,
            compact_context_lines = 3,
          },
        })
        require("code-review").setup({
          keymaps = false,
          comment = { storage = { backend = "file" } },
          ui = {
            input_window = { title = "Review (C-CR to submit)", height = 4, border = "single" },
            preview = { float = { border = "single" } },
          },
        })
      '';
    };
  };
}
