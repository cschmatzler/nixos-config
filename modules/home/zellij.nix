{
  lib,
  pkgs,
  ...
}: {
  programs.zellij = {
    enable = true;
    enableFishIntegration = lib.mkDefault false;
    settings = {
      theme = "catppuccin-latte";
      default_layout = "default";
      default_shell = "${pkgs.fish}/bin/fish";
      pane_frames = false;
      show_startup_tips = false;
      show_release_notes = false;
    };
  };

  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
      default_tab_template {
        pane split_direction="vertical" {
          pane
        }

        pane size=1 borderless=true {
          plugin location="file:${pkgs.zjstatus}/bin/zjstatus.wasm" {
            hide_frame_for_single_pane "true"

            format_left  "{mode}#[fg=#1e66f5,bg=#eff1f5,bold] {session}#[bg=#eff1f5] {tabs}"
            format_right "{datetime}"
            format_space "#[bg=#eff1f5]"

            mode_normal          "#[bg=#1e66f5] "
            mode_tab             "#[bg=#40a02b] "
            mode_pane            "#[bg=#8839ef] "
            mode_session         "#[bg=#179299] "
            mode_resize          "#[bg=#df8e1d] "
            mode_move            "#[bg=#ea76cb] "
            mode_search          "#[bg=#d20f39] "

            tab_normal               "#[fg=#6c6f85,bg=#eff1f5] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
            tab_active               "#[fg=#eff1f5,bg=#1e66f5,bold,underline] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
            tab_fullscreen_indicator "□ "
            tab_sync_indicator       "  "
            tab_floating_indicator   "󰉈 "

            datetime          "#[fg=#4c4f69,bg=#eff1f5] {format} "
            datetime_format   "%A, %d %b %Y %H:%M"
            datetime_timezone "Europe/Berlin"
          }
        }
      }
    }
  '';
}
