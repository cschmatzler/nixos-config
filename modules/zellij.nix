{...}: {
	den.aspects.zellij.homeManager = {pkgs, ...}: {
		programs.zellij.enable = true;

		xdg.configFile."zellij/config.kdl".text = ''
			default_layout "default"
			default_shell "${pkgs.nushell}/bin/nu"
			pane_frames false
			show_release_notes false
			show_startup_tips false
			theme "rose-pine-dawn"

			themes {
			  rose-pine-dawn {
			    text_unselected {
			      base 87 82 121
			      background 244 237 232
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    text_selected {
			      base 87 82 121
			      background 223 218 217
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    ribbon_selected {
			      base 244 237 232
			      background 40 105 131
			      emphasis_0 234 157 52
			      emphasis_1 215 130 126
			      emphasis_2 144 122 169
			      emphasis_3 86 148 159
			    }
			    ribbon_unselected {
			      base 250 244 237
			      background 87 82 121
			      emphasis_0 234 157 52
			      emphasis_1 215 130 126
			      emphasis_2 144 122 169
			      emphasis_3 86 148 159
			    }
			    table_title {
			      base 40 105 131
			      background 0 0 0
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    table_cell_selected {
			      base 87 82 121
			      background 223 218 217
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    table_cell_unselected {
			      base 87 82 121
			      background 244 237 232
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    list_selected {
			      base 87 82 121
			      background 223 218 217
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    list_unselected {
			      base 87 82 121
			      background 244 237 232
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 40 105 131
			      emphasis_3 144 122 169
			    }
			    frame_selected {
			      base 40 105 131
			      background 0 0 0
			      emphasis_0 215 130 126
			      emphasis_1 86 148 159
			      emphasis_2 144 122 169
			      emphasis_3 0 0 0
			    }
			    frame_highlight {
			      base 215 130 126
			      background 0 0 0
			      emphasis_0 215 130 126
			      emphasis_1 215 130 126
			      emphasis_2 215 130 126
			      emphasis_3 215 130 126
			    }
			    exit_code_success {
			      base 40 105 131
			      background 0 0 0
			      emphasis_0 86 148 159
			      emphasis_1 244 237 232
			      emphasis_2 144 122 169
			      emphasis_3 40 105 131
			    }
			    exit_code_error {
			      base 180 99 122
			      background 0 0 0
			      emphasis_0 234 157 52
			      emphasis_1 0 0 0
			      emphasis_2 0 0 0
			      emphasis_3 0 0 0
			    }
			    multiplayer_user_colors {
			      player_1 144 122 169
			      player_2 40 105 131
			      player_3 215 130 126
			      player_4 234 157 52
			      player_5 86 148 159
			      player_6 180 99 122
			      player_7 0 0 0
			      player_8 0 0 0
			      player_9 0 0 0
			      player_10 0 0 0
			    }
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
