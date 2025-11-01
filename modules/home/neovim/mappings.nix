{
  programs.nixvim.keymaps = [
    # clipboard - OSC52 yank and paste
    {
      mode = ["n" "v"];
      key = "<leader>y";
      action = ''"+y'';
      options.desc = "Yank to system clipboard (OSC52)";
    }
    # e - explore/edit
    {
      mode = "n";
      key = "<leader>ef";
      action = ":lua require('oil').open()<CR>";
      options.desc = "File directory";
    }
    {
      mode = "n";
      key = "<leader>er";
      action = ":lua require('grug-far').open()<CR>";
      options.desc = "Search and replace";
    }
    # f - find
    {
      mode = "n";
      key = "<leader>f/";
      action = ":Pick history scope='/'<CR>";
      options.desc = "'/' history";
    }
    {
      mode = "n";
      key = "<leader>f:";
      action = ":Pick history scope=':'<CR>";
      options.desc = "':' history";
    }
    {
      mode = "n";
      key = "<leader>fa";
      action = ":Pick git_hunks scope='staged'<CR>";
      options.desc = "Added hunks (all)";
    }
    {
      mode = "n";
      key = "<leader>fA";
      action = ":Pick git_hunks path='%' scope='staged'<CR>";
      options.desc = "Added hunks (buffer)";
    }
    {
      mode = "n";
      key = "<leader>fb";
      action = ":Pick buffers<CR>";
      options.desc = "Buffers";
    }
    {
      mode = "n";
      key = "<leader>fd";
      action = ":Pick diagnostic scope='all'<CR>";
      options.desc = "Diagnostic (workspace)";
    }
    {
      mode = "n";
      key = "<leader>fD";
      action = ":Pick diagnostic scope='current'<CR>";
      options.desc = "Diagnostic (buffer)";
    }
    {
      mode = "n";
      key = "<leader>ff";
      action = ":Pick files<CR>";
      options.desc = "Search files";
    }
    {
      mode = "n";
      key = "<leader>fg";
      action = ":Pick grep_live<CR>";
      options.desc = "Grep";
    }
    {
      mode = "n";
      key = "<leader>fm";
      action = ":Pick git_hunks<CR>";
      options.desc = "Modified hunks (all)";
    }
    {
      mode = "n";
      key = "<leader>fM";
      action = ":Pick git_hunks path='%'<CR>";
      options.desc = "Modified hunks (buffer)";
    }
    {
      mode = "n";
      key = "<leader>fr";
      action = ":Pick lsp scope='references'<CR>";
      options.desc = "References (LSP)";
    }
    {
      mode = "n";
      key = "<leader>fs";
      action = ":Pick lsp scope='workspace_symbol'<CR>";
      options.desc = "Symbols (LSP, workspace)";
    }
    {
      mode = "n";
      key = "<leader>fS";
      action = ":Pick lsp scope='document_symbol'<CR>";
      options.desc = "Symbols (LSP, buffer)";
    }
    {
      mode = "n";
      key = "<leader>fv";
      action = ":Pick visit_paths cwd=\"\"<CR>";
      options.desc = "Visit paths (all)";
    }
    {
      mode = "n";
      key = "<leader>fV";
      action = ":Pick visit_paths<CR>";
      options.desc = "Visit paths (cwd)";
    }
    # g - git
    {
      mode = "n";
      key = "<leader>gd";
      action = ":DiffviewOpen<CR>";
    }
    {
      mode = "n";
      key = "<leader>gg";
      action.__raw = ''
        function()
          require('neogit').open({})
        end
      '';
      options.desc = "Neogit";
    }
    # l - lsp/formatter
    {
      mode = "n";
      key = "<leader>la";
      action = ":lua vim.lsp.buf.code_action()<CR>";
      options.desc = "Actions";
    }
    {
      mode = "n";
      key = "<leader>ld";
      action = ":lua vim.diagnostic.open_float({ severity = { min = vim.diagnostic.severity.HINT } })<CR>";
      options.desc = "Diagnostics popup";
    }
    {
      mode = "n";
      key = "<leader>lf";
      action = ":lua require('conform').format({ lsp_fallback = true })<CR>";
      options.desc = "Format";
    }
    {
      mode = "n";
      key = "<leader>li";
      action = ":lua vim.lsp.buf.hover()<CR>";
      options.desc = "Information";
    }
    {
      mode = "n";
      key = "<leader>lj";
      action = ":lua vim.diagnostic.goto_next()<CR>";
      options.desc = "Next diagnostic";
    }
    {
      mode = "n";
      key = "<leader>lk";
      action = ":lua vim.diagnostic.goto_prev()<CR>";
      options.desc = "Prev diagnostic";
    }
    {
      mode = "n";
      key = "<leader>lr";
      action = ":lua vim.lsp.buf.rename()<CR>";
      options.desc = "Rename";
    }
    {
      mode = "n";
      key = "<leader>lR";
      action = ":lua vim.lsp.buf.references()<CR>";
      options.desc = "References";
    }
    {
      mode = "n";
      key = "<leader>ls";
      action = ":lua vim.lsp.buf.definition()<CR>";
      options.desc = "Source definition";
    }
    # other
    {
      mode = "n";
      key = "<leader>j";
      action = ":lua require('mini.jump2d').start(require('mini.jump2d').builtin_opts.query)<CR>";
      options.desc = "Jump to character";
    }
    {
      mode = "n";
      key = "<leader>a";
      action = ":lua require('harpoon'):list():add()<CR>";
      options.desc = "Add harpoon";
    }
    {
      mode = "n";
      key = "<C-e>";
      action = ":lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())<CR>";
      options.desc = "Toggle harpoon quick menu";
    }
    {
      mode = "n";
      key = "<leader>1";
      action = ":lua require('harpoon'):list():select(1)<CR>";
      options.desc = "Go to harpoon 1";
    }
    {
      mode = "n";
      key = "<leader>2";
      action = ":lua require('harpoon'):list():select(2)<CR>";
      options.desc = "Go to harpoon 2";
    }
    {
      mode = "n";
      key = "<leader>3";
      action = ":lua require('harpoon'):list():select(3)<CR>";
      options.desc = "Go to harpoon 3";
    }
    {
      mode = "n";
      key = "<leader>4";
      action = ":lua require('harpoon'):list():select(4)<CR>";
      options.desc = "Go to harpoon 4";
    }
  ];
}
