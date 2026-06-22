{...}: let
	theme = (import ./_lib/theme.nix).catppuccinLatte;
in {
	den.aspects.herdr.homeManager = {
		config,
		inputs',
		lib,
		pkgs,
		...
	}: let
		pluginRoot = "${config.home.homeDirectory}/.config/herdr/plugins/jj-worktrees";
	in {
		home.packages = [
			inputs'.herdr.packages.herdr
		];

		home.file.".config/herdr/plugins/jj-worktrees/herdr-plugin.toml".text = ''
			id = "cschmatzler.jj-worktrees"
			name = "JJ Worktrees"
			version = "0.1.0"
			min_herdr_version = "0.7.0"
			description = "Native Jujutsu workspace/worktree management for Herdr"
			platforms = ["linux", "macos"]

			[[actions]]
			id = "create"
			title = "Create JJ workspace"
			description = "Create and open a new jj workspace without prompting"
			contexts = ["workspace", "pane"]
			command = ["${pluginRoot}/jj-worktree-create.sh"]

			[[actions]]
			id = "remove-current"
			title = "Remove current JJ workspace"
			description = "Forget and delete the current jj workspace without prompting"
			contexts = ["workspace", "pane"]
			command = ["${pluginRoot}/jj-worktree-remove-current.sh"]
		'';

		home.file.".config/herdr/plugins/jj-worktrees/jj-worktree-create.sh" = {
			executable = true;
			text = ''
				#!/usr/bin/env bash
				set -euo pipefail

				herdr_bin="''${HERDR_BIN_PATH:-${inputs'.herdr.packages.herdr}/bin/herdr}"
				jj_bin="${pkgs.jujutsu}/bin/jj"
				jq_bin="${pkgs.jq}/bin/jq"

				cwd="''${HERDR_ACTIVE_PANE_CWD:-$PWD}"
				root="$($jj_bin -R "$cwd" root)"
				repo_name="$(basename "$root")"
				worktree_root="''${HERDR_JJ_WORKTREE_DIR:-$HOME/Projects/worktrees}/$repo_name"

				base="$($jj_bin -R "$root" log -r @ --no-graph -T 'change_id.short()' 2>/dev/null | tr -d '\n' || true)"
				if [ -z "$base" ]; then
					base="$(date +%Y%m%d-%H%M%S)"
				fi

				name="$base"
				if $jj_bin -R "$root" workspace list -T 'name ++ "\n"' | grep -Fxq "$name"; then
					name="$base-$(date +%H%M%S)"
				fi

				path="$worktree_root/$name"
				mkdir -p "$worktree_root"
				"$jj_bin" -R "$root" workspace add --name "$name" "$path"
				"$herdr_bin" workspace create --cwd "$path" --label "$repo_name:$name" --focus >/dev/null
			'';
		};

		home.file.".config/herdr/plugins/jj-worktrees/jj-worktree-remove-current.sh" = {
			executable = true;
			text = ''
				#!/usr/bin/env bash
				set -euo pipefail

				herdr_bin="''${HERDR_BIN_PATH:-${inputs'.herdr.packages.herdr}/bin/herdr}"
				jj_bin="${pkgs.jujutsu}/bin/jj"
				jq_bin="${pkgs.jq}/bin/jq"

				cwd="''${HERDR_ACTIVE_PANE_CWD:-$PWD}"
				current_root="$($jj_bin -R "$cwd" root)"
				workspace_rows="$($jj_bin -R "$current_root" workspace list -T 'name ++ "\t" ++ root ++ "\n"')"
				workspace_count="$(printf '%s\n' "$workspace_rows" | sed '/^$/d' | wc -l | tr -d ' ')"

				if [ "$workspace_count" -le 1 ]; then
					exit 0
				fi

				current_name="$(printf '%s\n' "$workspace_rows" | awk -F '\t' -v root="$current_root" '$2 == root { print $1; exit }')"
				if [ -z "$current_name" ] || [ "$current_name" = "default" ]; then
					exit 0
				fi

				fallback="$(printf '%s\n' "$workspace_rows" | awk -F '\t' -v root="$current_root" '$2 != root { print; exit }')"
				fallback_path="''${fallback#*$'\t'}"
				active_workspace_id="''${HERDR_ACTIVE_WORKSPACE_ID:-}"

				cd /tmp
				if [ -n "$active_workspace_id" ]; then
					"$herdr_bin" workspace close "$active_workspace_id" >/dev/null
				fi
				"$jj_bin" -R "$fallback_path" workspace forget "$current_name"
				rm -rf --one-file-system "$current_root"
			'';
		};

		home.file.".config/herdr/plugins/jj-worktrees/plugin.json".text = ''
			{
			  "plugin_id": "cschmatzler.jj-worktrees",
			  "name": "JJ Worktrees",
			  "version": "0.1.0",
			  "min_herdr_version": "0.7.0",
			  "description": "Native Jujutsu workspace/worktree management for Herdr",
			  "manifest_path": "${pluginRoot}/herdr-plugin.toml",
			  "plugin_root": "${pluginRoot}",
			  "enabled": true,
			  "platforms": ["linux", "macos"],
			  "actions": [
			    {
			      "id": "create",
			      "title": "Create JJ workspace",
			      "description": "Create and open a new jj workspace without prompting",
			      "contexts": ["workspace", "pane"],
			      "command": ["${pluginRoot}/jj-worktree-create.sh"]
			    },
			    {
			      "id": "remove-current",
			      "title": "Remove current JJ workspace",
			      "description": "Forget and delete the current jj workspace without prompting",
			      "contexts": ["workspace", "pane"],
			      "command": ["${pluginRoot}/jj-worktree-remove-current.sh"]
			    }
			  ],
			  "panes": [],
			  "source": { "kind": "local" }
			}
		'';

		home.activation.herdrJjWorktreesPlugin =
			lib.hm.dag.entryAfter ["writeBoundary"] ''
				set -eu
				registry="${config.home.homeDirectory}/.config/herdr/plugins.json"
				plugin_json="${pluginRoot}/plugin.json"
				mkdir -p "$(dirname "$registry")"

				if [ -e "$registry" ] && [ ! -L "$registry" ]; then
					tmp="$(mktemp)"
					${pkgs.jq}/bin/jq --slurpfile plugin "$plugin_json" '
						(if type == "array" then . else [] end)
						| map(select(.plugin_id != $plugin[0].plugin_id))
						+ [$plugin[0]]
					' "$registry" > "$tmp"
					mv "$tmp" "$registry"
				else
					${pkgs.jq}/bin/jq -n --slurpfile plugin "$plugin_json" '[$plugin[0]]' > "$registry"
				fi
			'';

		home.file.".config/herdr/config.toml".text = ''
			onboarding = false

			[theme]
			name = "${theme.slug}"

			[terminal]
			default_shell = "fish"
			new_cwd = "follow"
			shell_mode = "auto"

			[worktrees]
			directory = "~/Projects/worktrees"

			[ui]
			sidebar_width = 32
			sidebar_min_width = 18
			sidebar_max_width = 36
			mouse_capture = true
			right_click_passthrough_modifier = "ctrl"
			mouse_scroll_lines = 3
			confirm_close = false
			show_agent_labels_on_pane_borders = true
			agent_panel_scope = "all"
			prompt_new_tab_name = true
			accent = "${theme.hex.mauve}"

			[ui.toast]
			delivery = "terminal"
			delay_seconds = 1

			[ui.sound]
			enabled = false

			[session]
			resume_agents_on_restore = true

			[remote]
			manage_ssh_config = true

			[experimental]
			pane_history = true
			allow_nested = false
			kitty_graphics = true

			[advanced]
			scrollback_limit_bytes = 50000000

			[keys]
			prefix = "ctrl+b"

			help = "prefix+?"
			settings = "prefix+shift+s"
			detach = ["prefix+d", "prefix+q"]
			reload_config = "prefix+r"
			goto = "prefix+g"
			last_pane = "prefix+backtick"
			open_notification_target = "prefix+o"

			workspace_picker = ["prefix+s", "prefix+w"]
			new_workspace = "prefix+shift+n"
			rename_workspace = "prefix+shift+w"
			close_workspace = "prefix+shift+d"
			previous_workspace = "prefix+("
			next_workspace = "prefix+)"
			switch_workspace = "prefix+shift+1..9"

			focus_agent = "prefix+alt+1..9"
			previous_agent = "prefix+["
			next_agent = "prefix+]"

			new_tab = "prefix+c"
			previous_tab = "prefix+p"
			next_tab = "prefix+n"
			switch_tab = "prefix+1..9"
			rename_tab = "prefix+comma"
			close_tab = "prefix+shift+x"

			split_vertical = "prefix+backslash"
			split_horizontal = "prefix+enter"
			close_pane = "prefix+x"
			zoom = "prefix+m"
			copy_mode = "prefix+v"
			resize_mode = "prefix+shift+r"
			focus_pane_left = ["ctrl+h"]
			focus_pane_down = ["ctrl+j"]
			focus_pane_up = ["ctrl+k"]
			focus_pane_right = ["ctrl+l"]
			cycle_pane_next = "prefix+tab"
			cycle_pane_previous = "prefix+shift+tab"
			toggle_sidebar = "prefix+b"

			new_worktree = ""
			open_worktree = ""
			remove_worktree = ""

			navigate_workspace_up = "up"
			navigate_workspace_down = "down"
			navigate_pane_left = "h"
			navigate_pane_down = "j"
			navigate_pane_up = "k"
			navigate_pane_right = "l"

			[[keys.command]]
			key = "prefix+shift+g"
			type = "shell"
			command = "${pluginRoot}/jj-worktree-create.sh"
			description = "Create JJ workspace"

			[[keys.command]]
			key = "prefix+backspace"
			type = "shell"
			command = "${pluginRoot}/jj-worktree-remove-current.sh"
			description = "Remove current JJ workspace"

		'';
	};
}
