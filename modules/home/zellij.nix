{
  lib,
  pkgs,
  ...
}: {
  programs.zellij = {
    enable = true;
    enableFishIntegration = lib.mkDefault false;
    settings = {
      theme = "catppuccin-mocha";
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

            format_left  "{mode}#[fg=#89b4fa,bg=#1e1e2e,bold] {session}#[bg=#1e1e2e] {tabs}"
            format_right "{datetime}"
            format_space "#[bg=#1e1e2e]"

            mode_normal          "#[fg=#1e1e2e,bg=#89b4fa] "
            mode_locked          "#[fg=#1e1e2e,bg=#fab387] L "
            mode_tab             "#[fg=#1e1e2e,bg=#a6e3a1] T "
            mode_pane            "#[fg=#1e1e2e,bg=#cba6f7] P "
            mode_session         "#[fg=#1e1e2e,bg=#94e2d5] S "
            mode_resize          "#[fg=#1e1e2e,bg=#f9e2af] R "
            mode_move            "#[fg=#1e1e2e,bg=#f5c2e7] M "
            mode_search          "#[fg=#1e1e2e,bg=#f38ba8] S "

            tab_normal               "#[fg=#6c7086,bg=#1e1e2e] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
            tab_active               "#[fg=#1e1e2e,bg=#89b4fa,bold,underline] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
            tab_fullscreen_indicator "□ "
            tab_sync_indicator       "  "
            tab_floating_indicator   "󰉈 "

            datetime          "#[fg=#cdd6f4,bg=#1e1e2e] {format} "
            datetime_format   "%A, %d %b %Y %H:%M"
            datetime_timezone "Europe/Berlin"
          }
        }
      }
    }
  '';
}
