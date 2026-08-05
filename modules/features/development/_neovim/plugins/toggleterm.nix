{
  programs.nixvim.plugins.toggleterm = {
    enable = true;
    settings = {
      open_mapping = null;
      direction = "float";
      float_opts = {
        border = "curved";
        winblend = 3;
      };
      size = 20;
      hide_numbers = true;
      shade_terminals = true;
      shading_factor = 2;
      start_in_insert = true;
      close_on_exit = true;
      shell = "fish";
    };
  };
}
