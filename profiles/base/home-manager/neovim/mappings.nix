{
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>lf";
      action = ":lua require('conform').format({ lsp_fallback = true })<CR>";
      options.desc = "Format";
    }
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
    {
      mode = "n";
      key = "<leader>e";
      action = ":Oil<CR>";
      options.desc = "File browser";
    }
  ];
}
