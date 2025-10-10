{pkgs, ...}:
{
  programs.zed-editor = {
    enable = true;
    extraPackages = [
      pkgs.vtsls
    ];
    userSettings = {
      theme = {
        mode = "system";
        light = "One Light";
        dark = "Catppuccin Mocha";
      };
      buffer_font_family = "Iosevka Nerd Font";
      buffer_font_size = 17;
      ui_font_family = "Iosevka Nerd Font";
      ui_font_size = 16;
      vim_mode = true;
      ssh_connections = [
        {
          host = "tahani";
          projects = [
            {
              paths = [
                "/home/cschmatzler/Projects/Personal/shnosh"
              ];
            }
          ];
        }
      ];
      format_on_save = "off";
      buffer_font_features = {
        calt = 0;
      };
      inlay_hints = {
        enabled = true;
        show_value_hints = true;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;
        show_background = false;
        edit_debounce_ms = 700;
        scroll_debounce_ms = 50;
        toggle_on_modifiers_press = {
          control = false;
          alt = false;
          shift = false;
          platform = false;
          function = false;
        };
      };
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
    };
  };
}
