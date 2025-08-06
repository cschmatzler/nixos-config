{
  programs.nixvim.plugins.mini = {
    enable = true;
    modules = {
      basics = {
        options = {
          basic = true;
          extra_ui = true;
        };
        mappings = {
          basic = false;
        };
        autocommands = {
          basic = true;
        };
      };
      icons = {};
      statusline = {};
      extra = {};
      ai = {
        custom_textobjects = {
          B.__raw = "require('mini.extra').gen_ai_spec.buffer()";
          F.__raw = "require('mini.ai').gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' })";
        };
      };
      align = {};
      diff = {};
      git = {};
      bracketed = {};
      comment = {};
      completion = {
        lsp_completion = {
          source_func = "omnifunc";
        };
      };
      indentscope = {};
      move = {};
      starter = {};
      pairs = {};
      trailspace = {};
      visits = {};
      pick = {};
      surround = {};
      clue = {
        clues.__raw = ''
          {
            { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
            { mode = 'n', keys = '<Leader>e', desc = '+Explore' },
            { mode = 'n', keys = '<Leader>f', desc = '+Find' },
            { mode = 'n', keys = '<Leader>g', desc = '+Git' },
            { mode = 'n', keys = '<Leader>l', desc = '+LSP' },
            { mode = 'n', keys = '<Leader>L', desc = '+Lua/Log' },
            { mode = 'n', keys = '<Leader>o', desc = '+Other' },
            { mode = 'n', keys = '<Leader>r', desc = '+R' },
            { mode = 'n', keys = '<Leader>t', desc = '+Terminal/Minitest' },
            { mode = 'n', keys = '<Leader>T', desc = '+Test' },
            { mode = 'n', keys = '<Leader>v', desc = '+Visits' },
            { mode = 'x', keys = '<Leader>l', desc = '+LSP' },
            { mode = 'x', keys = '<Leader>r', desc = '+R' },
            require("mini.clue").gen_clues.builtin_completion(),
            require("mini.clue").gen_clues.g(),
            require("mini.clue").gen_clues.marks(),
            require("mini.clue").gen_clues.registers(),
            require("mini.clue").gen_clues.windows({ submode_resize = true }),
            require("mini.clue").gen_clues.z(),
          }
        '';
        triggers = [
          {
            mode = "n";
            keys = "<Leader>";
          }
          {
            mode = "x";
            keys = "<Leader>";
          }
          {
            mode = "n";
            keys = "[";
          }
          {
            mode = "n";
            keys = "]";
          }
          {
            mode = "x";
            keys = "[";
          }
          {
            mode = "x";
            keys = "]";
          }
          {
            mode = "i";
            keys = "<C-x>";
          }
          {
            mode = "n";
            keys = "g";
          }
          {
            mode = "x";
            keys = "g";
          }

          {
            mode = "n";
            keys = "\"";
          }
          {
            mode = "x";
            keys = "\"";
          }
          {
            mode = "i";
            keys = "<C-r>";
          }
          {
            mode = "c";
            keys = "<C-r>";
          }
          {
            mode = "n";
            keys = "<C-w>";
          }
          {
            mode = "n";
            keys = "z";
          }
          {
            mode = "x";
            keys = "z";
          }
          {
            mode = "n";
            keys = "'";
          }
          {
            mode = "n";
            keys = "`";
          }
          {
            mode = "x";
            keys = "'";
          }
          {
            mode = "x";
            keys = "`";
          }
        ];
      };
    };
  };
}
