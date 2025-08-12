{
  programs.nixvim.plugins.conform-nvim = {
    enable = true;
    settings = {
      format_on_save = {};
      formatters_by_ft = {
        nix = ["alejandra"];
        javascript = ["prettier"];
        typescript = ["prettier"];
        elixir = ["mix"];
      };
    };
  };
}
