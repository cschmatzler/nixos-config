{
  programs.nixvim.plugins = {
    supermaven = {
      enable = true;
      settings = {
        keymaps = {
          accept_suggestion = "<Tab>";
          clear_suggestions = "<C-]>";
        };
      };
    };
  };
}
