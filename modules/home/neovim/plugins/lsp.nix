{
  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nil_ls.enable = true; # Nix
        ts_ls.enable = true; # TS/JS
        volar.enable = true; # Vue
        cssls.enable = true; # CSS
        dockerls.enable = true; # Docker
        elixirls.enable = true; # Elixir
      };
    };
  };
}
