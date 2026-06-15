{...}: let
	theme = (import ./_lib/theme.nix).catppuccinLatte;
in {
	den.aspects.herdr.homeManager = {inputs', ...}: {
		home.packages = [
			inputs'.herdr.packages.herdr
		];

		home.file.".config/herdr/config.toml".text = ''
			onboarding = false

			[theme]
			name = "${theme.slug}"

			[terminal]
			new_cwd = "follow"
			shell_mode = "auto"

			[worktrees]
			directory = "~/Projects/worktrees"

			[ui]
			show_agent_labels_on_pane_borders = true
			agent_panel_scope = "all"
			prompt_new_tab_name = false

			[ui.toast]
			delivery = "terminal"
			delay_seconds = 1

			[ui.sound]
			enabled = false

			[session]
			resume_agents_on_restore = true

			[advanced]
			scrollback_limit_bytes = 50000000

			[keys]
			prefix = "ctrl+semicolon"
			last_pane = "prefix+backtick"
			previous_workspace = "prefix+shift+left"
			next_workspace = "prefix+shift+right"
			switch_workspace = "prefix+shift+1..9"
			focus_agent = "prefix+ctrl+1..9"
			previous_agent = "prefix+["
			next_agent = "prefix+]"
			open_notification_target = "prefix+o"
			reload_config = "prefix+r"
			copy_mode = "prefix+v"
			split_vertical = "prefix+backslash"
			split_horizontal = "prefix+enter"
			zoom = "prefix+m"
			resize_mode = "prefix+shift+r"
			remove_worktree = "prefix+backspace"

			navigate_workspace_up = "k"
			navigate_workspace_down = "j"
			navigate_pane_up = "up"
			navigate_pane_down = "down"

		'';
	};
}
