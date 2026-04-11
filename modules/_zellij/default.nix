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
		default_mode "locked"
		pane_frames false
		show_release_notes false
		show_startup_tips false
		theme "${theme.slug}"

		keybinds clear-defaults=true {
		  normal {
		  }
		  locked {
		    bind "Ctrl g" { SwitchToMode "Normal"; }
		  }
		  resize {
		    bind "r" { SwitchToMode "Normal"; }
		    bind "h" "Left" { Resize "Increase Left"; }
		    bind "j" "Down" { Resize "Increase Down"; }
		    bind "k" "Up" { Resize "Increase Up"; }
		    bind "l" "Right" { Resize "Increase Right"; }
		    bind "H" { Resize "Decrease Left"; }
		    bind "J" { Resize "Decrease Down"; }
		    bind "K" { Resize "Decrease Up"; }
		    bind "L" { Resize "Decrease Right"; }
		    bind "=" "+" { Resize "Increase"; }
		    bind "-" { Resize "Decrease"; }
		  }
		  pane {
		    bind "p" { SwitchToMode "Normal"; }
		    bind "h" "Left" { MoveFocus "Left"; }
		    bind "l" "Right" { MoveFocus "Right"; }
		    bind "j" "Down" { MoveFocus "Down"; }
		    bind "k" "Up" { MoveFocus "Up"; }
		    bind "Tab" { SwitchFocus; }
		    bind "n" { NewPane; SwitchToMode "Locked"; }
		    bind "d" { NewPane "Down"; SwitchToMode "Locked"; }
		    bind "r" { NewPane "Right"; SwitchToMode "Locked"; }
		    bind "s" { NewPane "stacked"; SwitchToMode "Locked"; }
		    bind "x" { CloseFocus; SwitchToMode "Locked"; }
		    bind "f" { ToggleFocusFullscreen; SwitchToMode "Locked"; }
		    bind "z" { TogglePaneFrames; SwitchToMode "Locked"; }
		    bind "w" { ToggleFloatingPanes; SwitchToMode "Locked"; }
		    bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "Locked"; }
		    bind "c" { SwitchToMode "RenamePane"; PaneNameInput 0;}
		    bind "i" { TogglePanePinned; SwitchToMode "Locked"; }
		  }
		  move {
		    bind "m" { SwitchToMode "Normal"; }
		    bind "n" "Tab" { MovePane; }
		    bind "p" { MovePaneBackwards; }
		    bind "h" "Left" { MovePane "Left"; }
		    bind "j" "Down" { MovePane "Down"; }
		    bind "k" "Up" { MovePane "Up"; }
		    bind "l" "Right" { MovePane "Right"; }
		  }
		  tab {
		    bind "t" { SwitchToMode "Normal"; }
		    bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
		    bind "h" "Left" "Up" "k" { GoToPreviousTab; }
		    bind "l" "Right" "Down" "j" { GoToNextTab; }
		    bind "n" { NewTab; SwitchToMode "Locked"; }
		    bind "x" { CloseTab; SwitchToMode "Locked"; }
		    bind "s" { ToggleActiveSyncTab; SwitchToMode "Locked"; }
		    bind "b" { BreakPane; SwitchToMode "Locked"; }
		    bind "]" { BreakPaneRight; SwitchToMode "Locked"; }
		    bind "[" { BreakPaneLeft; SwitchToMode "Locked"; }
		    bind "1" { GoToTab 1; SwitchToMode "Locked"; }
		    bind "2" { GoToTab 2; SwitchToMode "Locked"; }
		    bind "3" { GoToTab 3; SwitchToMode "Locked"; }
		    bind "4" { GoToTab 4; SwitchToMode "Locked"; }
		    bind "5" { GoToTab 5; SwitchToMode "Locked"; }
		    bind "6" { GoToTab 6; SwitchToMode "Locked"; }
		    bind "7" { GoToTab 7; SwitchToMode "Locked"; }
		    bind "8" { GoToTab 8; SwitchToMode "Locked"; }
		    bind "9" { GoToTab 9; SwitchToMode "Locked"; }
		    bind "Tab" { ToggleTab; }
		  }
		  scroll {
		    bind "s" { SwitchToMode "Normal"; }
		    bind "e" { EditScrollback; SwitchToMode "Locked"; }
		    bind "f" { SwitchToMode "EnterSearch"; SearchInput 0; }
		    bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
		    bind "j" "Down" { ScrollDown; }
		    bind "k" "Up" { ScrollUp; }
		    bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
		    bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
		    bind "d" { HalfPageScrollDown; }
		    bind "u" { HalfPageScrollUp; }
		    bind "Alt left" { MoveFocusOrTab "left"; SwitchToMode "locked"; }
		    bind "Alt down" { MoveFocus "down"; SwitchToMode "locked"; }
		    bind "Alt up" { MoveFocus "up"; SwitchToMode "locked"; }
		    bind "Alt right" { MoveFocusOrTab "right"; SwitchToMode "locked"; }
		    bind "Alt h" { MoveFocusOrTab "left"; SwitchToMode "locked"; }
		    bind "Alt j" { MoveFocus "down"; SwitchToMode "locked"; }
		    bind "Alt k" { MoveFocus "up"; SwitchToMode "locked"; }
		    bind "Alt l" { MoveFocusOrTab "right"; SwitchToMode "locked"; }
		  }
		  search {
		    bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
		    bind "j" "Down" { ScrollDown; }
		    bind "k" "Up" { ScrollUp; }
		    bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
		    bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
		    bind "d" { HalfPageScrollDown; }
		    bind "u" { HalfPageScrollUp; }
		    bind "n" { Search "down"; }
		    bind "p" { Search "up"; }
		    bind "c" { SearchToggleOption "CaseSensitivity"; }
		    bind "w" { SearchToggleOption "Wrap"; }
		    bind "o" { SearchToggleOption "WholeWord"; }
		  }
		  entersearch {
		    bind "Ctrl c" "Esc" { SwitchToMode "Scroll"; }
		    bind "Enter" { SwitchToMode "Search"; }
		  }
		  renametab {
		    bind "Ctrl c" "Enter" { SwitchToMode "Locked"; }
		    bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
		  }
		  renamepane {
		    bind "Ctrl c" "Enter" { SwitchToMode "Locked"; }
		    bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
		  }
		  session {
		    bind "o" { SwitchToMode "Normal"; }
		    bind "d" { Detach; }
		    bind "w" {
		      LaunchOrFocusPlugin "session-manager" {
		        floating true
		        move_to_focused_tab true
		      };
		      SwitchToMode "Locked"
		    }
		    bind "c" {
		      LaunchOrFocusPlugin "configuration" {
		        floating true
		        move_to_focused_tab true
		      };
		      SwitchToMode "Locked"
		    }
		    bind "p" {
		      LaunchOrFocusPlugin "plugin-manager" {
		        floating true
		        move_to_focused_tab true
		      };
		      SwitchToMode "Locked"
		    }
		    bind "a" {
		      LaunchOrFocusPlugin "zellij:about" {
		        floating true
		        move_to_focused_tab true
		      };
		      SwitchToMode "Locked"
		    }
		    bind "s" {
		      LaunchOrFocusPlugin "zellij:share" {
		        floating true
		        move_to_focused_tab true
		      };
		      SwitchToMode "Locked"
		    }
		    bind "l" {
		      LaunchOrFocusPlugin "zellij:layout-manager" {
		        floating true
		        move_to_focused_tab true
		      };
		      SwitchToMode "Locked"
		    }
		  }
		  shared_except "locked" "renametab" "renamepane" {
		    bind "Ctrl g" { SwitchToMode "Locked"; }
		    bind "Ctrl q" { Quit; }
		  }
		  shared_except "renamepane" "renametab" "entersearch" "locked" {
		    bind "esc" { SwitchToMode "locked"; }
		  }
		  shared_among "normal" "locked" {
		    bind "Alt n" { NewPane; }
		    bind "Alt f" { ToggleFloatingPanes; }
		    bind "Alt i" { MoveTab "Left"; }
		    bind "Alt o" { MoveTab "Right"; }
		    bind "Alt h" "Alt Left" { MoveFocusOrTab "Left"; }
		    bind "Alt l" "Alt Right" { MoveFocusOrTab "Right"; }
		    bind "Alt j" "Alt Down" { MoveFocus "Down"; }
		    bind "Alt k" "Alt Up" { MoveFocus "Up"; }
		    bind "Alt =" "Alt +" { Resize "Increase"; }
		    bind "Alt -" { Resize "Decrease"; }
		    bind "Alt [" { PreviousSwapLayout; }
		    bind "Alt ]" { NextSwapLayout; }
		    bind "Alt p" { TogglePaneInGroup; }
		    bind "Alt Shift p" { ToggleGroupMarking; }
		  }
		  shared_except "locked" "renametab" "renamepane" {
		    bind "Enter" { SwitchToMode "Locked"; }
		  }
		  shared_except "pane" "locked" "renametab" "renamepane" "entersearch" {
		    bind "p" { SwitchToMode "Pane"; }
		  }
		  shared_except "resize" "locked" "renametab" "renamepane" "entersearch" {
		    bind "r" { SwitchToMode "Resize"; }
		  }
		  shared_except "scroll" "locked" "renametab" "renamepane" "entersearch" {
		    bind "s" { SwitchToMode "Scroll"; }
		  }
		  shared_except "session" "locked" "renametab" "renamepane" "entersearch" {
		    bind "o" { SwitchToMode "Session"; }
		  }
		  shared_except "tab" "locked" "renametab" "renamepane" "entersearch" {
		    bind "t" { SwitchToMode "Tab"; }
		  }
		  shared_except "move" "locked" "renametab" "renamepane" "entersearch" {
		    bind "m" { SwitchToMode "Move"; }
		  }
		}

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
