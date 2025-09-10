{
  programs.nixvim = {
    globals = {
      clipboard = "osc52";
    };
    opts = {
      expandtab = true;
      ignorecase = true;
      mouse = "";
      relativenumber = true;
      shiftwidth = 2;
      smartcase = true;
    };
  };
}
