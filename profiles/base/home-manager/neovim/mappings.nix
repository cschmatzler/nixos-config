{
  programs.nixvim.keymaps = [
    # e - explore/edit
    {
      mode = "n";
      key = "<leader>ed";
      action = ":lua require('mini.files').open()<CR>";
      options.desc = "Directory";
    }
    {
      mode = "n";
      key = "<leader>ef";
      action = ":lua require('mini.files').open(vim.api.nvim_buf_get_name(0))<CR>";
      options.desc = "File directory";
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
    # g - git
    {
      mode = "n";
      key = "<leader>gg";
      action = ":LazyGit<CR>";
      options.desc = "Lazygit";
    }
    # l - lsp/formatter
    {
      mode = "n";
      key = "<leader>lf";
      action = ":lua require('conform').format({ lsp_fallback = true })<CR>";
      options.desc = "Format";
    }
    # next
    {
      mode = "n";
      key = "<leader>/";
      action = ":Pick grep_live<CR>";
      options.desc = "Grep";
    }
    {
      mode = "n";
      key = "sj";
      action = ":lua require('mini.jump2d').start(require('mini.jump2d').builtin_opts.query)<CR>";
      options.desc = "Jump to character";
    }
  ];
}
