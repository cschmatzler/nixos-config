{
  programs.nixvim.plugins.mini = {
    enable = true;
    modules = {
      basics = {
        options = {
          basic = true;
          extra_ui = true;
          win_ui_borders = "dot";
        };
        mappings = {
          basic = true;
          windows = true;
          move_with_alt = true;
        };
        autocommands = {
          basic = true;
        };
      };
      icons = {};
      notify = {};
      sessions = {};
      statusline = {};
      extra = {};
      ai = {
        custom_textobjects = {
          B.__raw = "require('mini.extra').gen_ai_spec.buffer()";
          F.__raw = "require('mini.ai').gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' })";
        };
      };
      align = {};
      bracketed = {};
      bufremove = {};
      comment = {};
      completion = {
        lsp_completion = {
          source_func = "omnifunc";
        };
      };
      pick = {};
      surround = {};
    };
  };

  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>ff";
      action = ":Pick files<CR>";
      options.desc = "Search files";
    }
    {
      mode = "n";
      key = "<leader>/";
      action = ":Pick grep_live<CR>";
      options.desc = "Grep";
    }
  ];
}
