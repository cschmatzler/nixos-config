{
	pkgs,
	theme,
}: let
	palette = theme.hex;
	rgb = theme.rgb;
in {
	configKdl = ''
		default_layout "default"
		default_shell "${pkgs.nushell}/bin/nu"
		pane_frames false
		show_release_notes false
		show_startup_tips false
		theme "${theme.slug}"

		themes {
		  ${theme.slug} {
		    text_unselected {
		      base ${rgb.text}
		      background ${rgb.highlightLow}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    text_selected {
		      base ${rgb.text}
		      background ${rgb.highlightMed}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    ribbon_selected {
		      base ${rgb.highlightLow}
		      background ${rgb.pine}
		      emphasis_0 ${rgb.gold}
		      emphasis_1 ${rgb.rose}
		      emphasis_2 ${rgb.iris}
		      emphasis_3 ${rgb.foam}
		    }
		    ribbon_unselected {
		      base ${rgb.base}
		      background ${rgb.text}
		      emphasis_0 ${rgb.gold}
		      emphasis_1 ${rgb.rose}
		      emphasis_2 ${rgb.iris}
		      emphasis_3 ${rgb.foam}
		    }
		    table_title {
		      base ${rgb.pine}
		      background ${rgb.black}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    table_cell_selected {
		      base ${rgb.text}
		      background ${rgb.highlightMed}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    table_cell_unselected {
		      base ${rgb.text}
		      background ${rgb.highlightLow}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    list_selected {
		      base ${rgb.text}
		      background ${rgb.highlightMed}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    list_unselected {
		      base ${rgb.text}
		      background ${rgb.highlightLow}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.pine}
		      emphasis_3 ${rgb.iris}
		    }
		    frame_selected {
		      base ${rgb.pine}
		      background ${rgb.black}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.foam}
		      emphasis_2 ${rgb.iris}
		      emphasis_3 ${rgb.black}
		    }
		    frame_highlight {
		      base ${rgb.rose}
		      background ${rgb.black}
		      emphasis_0 ${rgb.rose}
		      emphasis_1 ${rgb.rose}
		      emphasis_2 ${rgb.rose}
		      emphasis_3 ${rgb.rose}
		    }
		    exit_code_success {
		      base ${rgb.pine}
		      background ${rgb.black}
		      emphasis_0 ${rgb.foam}
		      emphasis_1 ${rgb.highlightLow}
		      emphasis_2 ${rgb.iris}
		      emphasis_3 ${rgb.pine}
		    }
		    exit_code_error {
		      base ${rgb.love}
		      background ${rgb.black}
		      emphasis_0 ${rgb.gold}
		      emphasis_1 ${rgb.black}
		      emphasis_2 ${rgb.black}
		      emphasis_3 ${rgb.black}
		    }
		    multiplayer_user_colors {
		      player_1 ${rgb.iris}
		      player_2 ${rgb.pine}
		      player_3 ${rgb.rose}
		      player_4 ${rgb.gold}
		      player_5 ${rgb.foam}
		      player_6 ${rgb.love}
		      player_7 ${rgb.black}
		      player_8 ${rgb.black}
		      player_9 ${rgb.black}
		      player_10 ${rgb.black}
		    }
		  }
		}
	'';

	layoutKdl = ''
		layout {
		  default_tab_template {
		    pane split_direction="vertical" {
		      pane
		    }

		    pane size=1 borderless=true {
		      plugin location="file:${pkgs.zjstatus}/bin/zjstatus.wasm" {
		        format_left  "{mode}#[fg=${palette.pine},bg=${palette.base},bold] {session}#[bg=${palette.base}] {tabs}"
		        format_right "{datetime}"
		        format_space "#[bg=${palette.base}]"

		        mode_normal          "#[fg=${palette.base},bg=${palette.pine}] "
		        mode_locked          "#[fg=${palette.base},bg=${palette.gold}] L "
		        mode_tab             "#[fg=${palette.base},bg=${palette.leaf}] T "
		        mode_pane            "#[fg=${palette.base},bg=${palette.iris}] P "
		        mode_session         "#[fg=${palette.base},bg=${palette.foam}] S "
		        mode_resize          "#[fg=${palette.base},bg=${palette.gold}] R "
		        mode_move            "#[fg=${palette.base},bg=${palette.rose}] M "
		        mode_search          "#[fg=${palette.base},bg=${palette.love}] S "

		        tab_normal               "#[fg=${palette.muted},bg=${palette.base}] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
		        tab_active               "#[fg=${palette.base},bg=${palette.pine},bold,underline] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
		        tab_fullscreen_indicator "󰊓 "
		        tab_sync_indicator       "󰓦 "
		        tab_floating_indicator   "󰉈 "

		        datetime          "#[fg=${palette.text},bg=${palette.base}] {format} "
		        datetime_format   "%A, %d %b %Y %H:%M"
		        datetime_timezone "Europe/Berlin"
		      }
		    }
		  }
		}
	'';
}
