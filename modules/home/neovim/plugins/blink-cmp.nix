{
  programs.nixvim.plugins.blink-cmp = {
    enable = true;
    settings = {
      signature.enabled = true;
      completion = {
        accept = {
          auto_brackets = {
            enabled = true;
            semantic_token_resolution.enabled = false;
          };
        };
        documentation.auto_show = true;
      };
    };
  };
}
