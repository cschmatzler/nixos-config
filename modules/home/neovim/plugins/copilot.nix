{
  programs.nixvim.plugins.copilot-lua = {
    enable = true;
    settings = {
      panel.enabled = false;
      suggestion = {
        enabled = true;
        auto_trigger = true;
        keymap = {
          accept = "<Tab>";
        };
      };
    };
  };
}
