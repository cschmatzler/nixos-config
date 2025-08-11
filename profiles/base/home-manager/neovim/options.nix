{
  programs.nixvim.globalOpts = {
    expandtab = true;
    shiftwidth = 2;
    relativenumber = true;
    mouse = "";
    clipboard.register = "unnamedplus";
    # foldmethod = "expr";
    # foldexpr = "nvim_treesitter#foldexpr()";
  };
}
