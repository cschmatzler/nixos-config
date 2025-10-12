{
  programs.nixvim.plugins.neogit = {
    enable = true;
    settings = {
      disable_signs = false;
      integrations = {
        diffview = true;
      };
    };
  };
}
