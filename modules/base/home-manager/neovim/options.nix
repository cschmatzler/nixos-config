{
  programs.nixvim = {
    globals = {
      # clipboard = "osc52";
    };
    opts = {
      clipboard = "unnamedplus";
      expandtab = true;
      ignorecase = true;
      mouse = "";
      relativenumber = true;
      shiftwidth = 2;
      smartcase = true;
    };
  };
}
