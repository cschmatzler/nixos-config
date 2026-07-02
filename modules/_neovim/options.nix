{
  programs.nixvim = {
    globals = {
      clipboard = "osc52";
      mapleader = " ";
      maplocalleader = " ";
    };
    opts = {
      winborder = "single";
      expandtab = true;
      softtabstop = 2;
      tabstop = 2;
      ignorecase = true;
      list = false;
      mouse = "";
      relativenumber = true;
      scrolloff = 8;
      shiftwidth = 2;
      smartcase = true;
      undofile = true;
    };
  };
}
