{pkgs, ...}: {
  programs.nixvim.plugins = {
    flash = {
      enable = true;
      settings.modes.char.enabled = false;
    };
    grug-far.enable = true;
    hardtime.enable = true;
    harpoon.enable = true;
    hunk.enable = true;
    zk.enable = true;

    blink-cmp = {
      enable = true;
      settings = {
        keymap = {
          preset = "default";
          "<Tab>" = ["snippet_forward" "fallback"];
        };
        signature.enabled = true;
        completion = {
          accept.auto_brackets = {
            enabled = true;
            semantic_token_resolution.enabled = false;
          };
          documentation.auto_show = true;
        };
      };
    };

    conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      settings = {
        format_on_save = {};
        formatters_by_ft = {
          nix = ["alejandra"];
          javascript = ["oxfmt"];
          typescript = ["oxfmt"];
        };
      };
    };

    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        cssls.enable = true;
        dockerls.enable = true;
        jsonls.enable = true;
        nil_ls.enable = true;
        vtsls.enable = true;
        yamlls.enable = true;
        zk.enable = true;
      };
    };

    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "rose-pine";
          globalstatus = true;
          component_separators = {
            left = "│";
            right = "│";
          };
          section_separators = {
            left = "";
            right = "";
          };
        };
        sections = {
          lualine_a = ["mode"];
          lualine_b = ["branch" "diff"];
          lualine_c = ["filename"];
          lualine_x = ["diagnostics"];
          lualine_y = ["filetype"];
          lualine_z = ["location"];
        };
        inactive_sections = {
          lualine_a = [];
          lualine_b = [];
          lualine_c = ["filename"];
          lualine_x = ["location"];
          lualine_y = [];
          lualine_z = [];
        };
      };
    };

    mini = {
      enable = true;
      modules = {
        ai.custom_textobjects = {
          B.__raw = "require('mini.extra').gen_ai_spec.buffer()";
          F.__raw = "require('mini.ai').gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' })";
        };
        align = {};
        basics = {
          options = {
            basic = true;
            extra_ui = true;
          };
          mappings.basic = false;
          autocommands.basic = true;
        };
        bracketed = {};
        comment = {};
        diff = {};
        extra = {};
        hipatterns.highlighters = {
          fixme.__raw = "{ pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' }";
          hack.__raw = "{ pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' }";
          todo.__raw = "{ pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' }";
          note.__raw = "{ pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' }";
          hex_color.__raw = "require('mini.hipatterns').gen_highlighter.hex_color()";
        };
        jump = {};
        move = {};
        pairs = {};
        splitjoin = {};
        surround = {};
        trailspace = {};
      };
    };

    neogit = {
      enable = true;
      settings = {
        kind = "replace";
        commit_popup.kind = "floating";
        preview_buffer.kind = "floating";
        popup.kind = "floating";
        disable_commit_confirmation = true;
        diff_viewer = "codediff";
        integrations.codediff = true;
        sections = let
          open = {
            folded = false;
            hidden = false;
          };
          folded = {
            folded = true;
            hidden = false;
          };
        in {
          untracked = open;
          unstaged = open;
          staged = open;
          stashes = open;
          unpulled = open;
          unmerged = folded;
          recent = folded;
        };
      };
    };

    noice = {
      enable = true;
      settings = {
        cmdline = {
          enabled = true;
          view = "cmdline_popup";
        };
        messages = {
          enabled = true;
          view = "mini";
          view_error = "mini";
          view_warn = "mini";
          view_history = "split";
          view_search = "virtualtext";
        };
        notify.enabled = false;
        popupmenu = {
          enabled = true;
          backend = "nui";
        };
        lsp = {
          progress = {
            enabled = true;
            view = "mini";
          };
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            "cmp.entry.get_documentation" = true;
          };
        };
        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          lsp_doc_border = true;
        };
        views = {
          cmdline_popup.border = {
            style = "single";
            padding = [0 1];
          };
          popup.border = {
            style = "single";
            padding = [0 1];
          };
        };
      };
    };

    oil = {
      enable = true;
      settings = {
        keymaps = {
          "<C-r>" = "actions.refresh";
          "<leader>qq" = "actions.close";
        };
        skip_confirm_for_simple_edits = true;
        constrain_cursor = "editable";
        default_file_explorer = true;
        view_options.show_hidden = true;
        win_options = {
          concealcursor = "ncv";
          conceallevel = 3;
          cursorcolumn = false;
          foldcolumn = "0";
          list = false;
          signcolumn = "no";
          spell = false;
          wrap = false;
        };
      };
    };

    render-markdown = {
      enable = true;
      settings = {
        anti_conceal.enabled = false;
        file_types = ["markdown"];
      };
    };

    snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        indent.enabled = true;
        dashboard = {
          enabled = true;
          sections = [
            {section = "header";}
            {
              section = "keys";
              gap = 1;
            }
            {
              icon = " ";
              title = "Recent Files";
              section = "recent_files";
              indent = 2;
              padding = [2 2];
            }
            {
              icon = " ";
              title = "Projects";
              section = "projects";
              indent = 2;
              padding = 2;
            }
          ];
        };
        input.enabled = true;
        notifier.enabled = true;
        picker = {
          enabled = true;
          ui_select = true;
          layout.layout.backdrop = false;
        };
        quickfile.enabled = true;
        scope.enabled = true;
        statuscolumn.enabled = true;
        words = {
          enabled = true;
          debounce = 150;
          notify_jump = false;
          notify_end = false;
        };
      };
    };

    toggleterm = {
      enable = true;
      settings = {
        open_mapping = null;
        direction = "float";
        float_opts = {
          border = "curved";
          winblend = 3;
        };
        size = 20;
        hide_numbers = true;
        shade_terminals = true;
        shading_factor = 2;
        start_in_insert = true;
        close_on_exit = true;
        shell = "fish";
      };
    };

    treesitter = {
      enable = true;
      nixGrammars = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
        bash
        css
        diff
        elixir
        javascript
        lua
        markdown
        markdown_inline
        nix
        regex
        typescript
        vim
      ];
      settings.highlight.enable = true;
    };

    which-key = {
      enable = true;
      settings = {
        delay.__raw = ''
          function(ctx)
            return ctx.plugin and 0 or 150
          end
        '';
        notify = false;
        plugins = {
          marks = true;
          registers = true;
          spelling = {
            enabled = true;
            suggestions = 20;
          };
          presets = {
            operators = true;
            motions = true;
            text_objects = true;
            windows = true;
            nav = true;
            z = true;
            g = true;
          };
        };
        win = {
          border = "single";
          padding = [1 2];
          title = true;
          title_pos = "center";
        };
        layout = {
          width.min = 24;
          spacing = 3;
        };
        spec = [
          {
            __unkeyed-1 = "<leader>e";
            group = "Explore";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "Find";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>l";
            mode = ["n" "x"];
            group = "LSP";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>r";
            mode = ["n" "v"];
            group = "Review";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "Tab";
            icon = "󰓩 ";
          }
          {
            __unkeyed-1 = "<leader>v";
            group = "VCS";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>w";
            group = "Window";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>z";
            group = "Notes";
            icon = "󰠮 ";
          }
        ];
      };
    };
  };
}
