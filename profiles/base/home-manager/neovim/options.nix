{
  programs.nixvim.globalOpts = {
    expandtab = true;
    shiftwidth = 2;
    relativenumber = true;
    mouse = "";
    clipboard = "osc52";
    # foldmethod = "expr";
    # foldexpr = "nvim_treesitter#foldexpr()";
  };
}
