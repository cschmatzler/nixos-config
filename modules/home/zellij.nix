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

            mode_normal          "#[fg=#eff1f5,bg=#1e66f5] "
            mode_locked          "#[fg=#eff1f5,bg=#fe640b] L "
            mode_tab             "#[fg=#eff1f5,bg=#40a02b] T "
            mode_pane            "#[fg=#eff1f5,bg=#8839ef] P "
            mode_session         "#[fg=#eff1f5,bg=#179299] S "
            mode_resize          "#[fg=#eff1f5,bg=#df8e1d] R "
            mode_move            "#[fg=#eff1f5,bg=#ea76cb] M "
            mode_search          "#[fg=#eff1f5,bg=#d20f39] S "

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
