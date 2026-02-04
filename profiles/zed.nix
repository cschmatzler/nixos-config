{
	pkgs,
	lib,
	user,
	...
}: {
	programs.zed-editor = {
		enable = true;
		extensions = [
			"catppuccin"
			"catppuccin-icons"
			"nix"
			"elixir"
			"html"
			"toml"
			"sql"
			"dockerfile"
			"make"
			"git-firefly"
		];
		userSettings = {
			vim_mode = true;
			ui_font_size = 16;
			buffer_font_size = 16;
			buffer_font_family = "TX-02";
			theme = {
				mode = "system";
				light = "Catppuccin Latte";
				dark = "Catppuccin Mocha";
			};
			icon_theme = "Catppuccin Latte";
			tab_bar = {
				show = false;
			};
			toolbar = {
				breadcrumbs = false;
				quick_actions = false;
				selections_menu = false;
			};
			scrollbar = {
				show = "never";
			};
			indent_guides = {
				enabled = true;
				coloring = "indent_aware";
			};
			inlay_hints = {
				enabled = true;
			};
			ssh_connections = [
				{
					host = "tahani";
					projects = [];
				}
			];
		};
		userKeymaps = [
			{
				context = "Editor && VimControl && !VimWaiting && !menu";
				bindings = {
					"space f f" = "file_finder::Toggle";
					"space f g" = "pane::DeploySearch";
					"space e" = "workspace::ToggleLeftDock";
					"space b d" = "pane::CloseActiveItem";
					"space b n" = "pane::ActivateNextItem";
					"space b p" = "pane::ActivatePrevItem";
					"space q" = "workspace::CloseWindow";
					"space w v" = "pane::SplitRight";
					"space w s" = "pane::SplitDown";
					"ctrl-h" = ["workspace::ActivatePaneInDirection" "Left"];
					"ctrl-l" = ["workspace::ActivatePaneInDirection" "Right"];
					"ctrl-j" = ["workspace::ActivatePaneInDirection" "Down"];
					"ctrl-k" = ["workspace::ActivatePaneInDirection" "Up"];
					"g r" = "editor::FindAllReferences";
				};
			}
			{
				context = "Editor && vim_mode == insert";
				bindings = {
					"j k" = "vim::NormalBefore";
				};
			}
			{
				context = "ProjectPanel && not_editing";
				bindings = {
					"a" = "project_panel::NewFile";
					"A" = "project_panel::NewDirectory";
					"r" = "project_panel::Rename";
					"d" = "project_panel::Delete";
					"x" = "project_panel::Cut";
					"y" = "project_panel::Copy";
					"p" = "project_panel::Paste";
				};
			}
		];
	};
}
