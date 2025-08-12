{
  programs.nixvim = {
    globalOpts = {
      expandtab = true;
      shiftwidth = 2;
      relativenumber = true;
      mouse = "";
      # foldmethod = "expr";
      # foldexpr = "nvim_treesitter#foldexpr()";
    };
    globals = {
      clipboard = "osc52";
    };
    opts = {
      ignorecase = true;
      smartcase = true;
    };
  };
}
