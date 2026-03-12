{...}: {
	den.aspects.zellij.homeManager = {pkgs, ...}: {
		programs.zellij = {
			enable = true;
			settings = {
				theme = "rose-pine-dawn";
				default_layout = "default";
				default_shell = "${pkgs.nushell}/bin/nu";
				pane_frames = false;
				show_startup_tips = false;
				show_release_notes = false;
			};
		};

		xdg.configFile."zellij/themes/rose-pine-dawn.kdl".text = ''
			themes {
			  rose-pine-dawn {
			    fg "#575279"
			    bg "#f2e9e1"
			    black "#faf4ed"
			    red "#b4637a"
			    green "#6d8f89"
			    yellow "#ea9d34"
			    blue "#286983"
			    magenta "#907aa9"
			    cyan "#56949f"
			    white "#575279"
			    orange "#d7827e"
			  }
			}
		'';

		xdg.configFile."zellij/layouts/default.kdl".text = ''
			layout {
			  default_tab_template {
			    pane split_direction="vertical" {
			      pane
			    }

			    pane size=1 borderless=true {
			      plugin location="file:${pkgs.zjstatus}/bin/zjstatus.wasm" {
			        hide_frame_for_single_pane "true"

			        format_left  "{mode}#[fg=#286983,bg=#faf4ed,bold] {session}#[bg=#faf4ed] {tabs}"
			        format_right "{datetime}"
			        format_space "#[bg=#faf4ed]"

			        mode_normal          "#[fg=#faf4ed,bg=#286983] "
			        mode_locked          "#[fg=#faf4ed,bg=#ea9d34] L "
			        mode_tab             "#[fg=#faf4ed,bg=#6d8f89] T "
			        mode_pane            "#[fg=#faf4ed,bg=#907aa9] P "
			        mode_session         "#[fg=#faf4ed,bg=#56949f] S "
			        mode_resize          "#[fg=#faf4ed,bg=#ea9d34] R "
			        mode_move            "#[fg=#faf4ed,bg=#d7827e] M "
			        mode_search          "#[fg=#faf4ed,bg=#b4637a] S "

			        tab_normal               "#[fg=#9893a5,bg=#faf4ed] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
			        tab_active               "#[fg=#faf4ed,bg=#286983,bold,underline] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
			        tab_fullscreen_indicator "󰊓 "
			        tab_sync_indicator       "󰓦 "
			        tab_floating_indicator   "󰉈 "

			        datetime          "#[fg=#575279,bg=#faf4ed] {format} "
			        datetime_format   "%A, %d %b %Y %H:%M"
			        datetime_timezone "Europe/Berlin"
			      }
			    }
			  }
			}
		'';
	};
}
