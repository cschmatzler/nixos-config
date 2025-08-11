{
  programs.nixvim.globalOpts = {
    expandtab = true;
    shiftwidth = 2;
    relativenumber = true;
    # foldmethod = "expr";
    # foldexpr = "nvim_treesitter#foldexpr()";
  };
}
