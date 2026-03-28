{...}: let
	local = import ./_lib/local.nix;
	theme = (import ./_lib/theme.nix).rosePineDawn;
	palette = theme.hex;
	pineAnsi = builtins.replaceStrings [" "] [";"] theme.rgb.pine;
in {
	den.aspects.shell.homeManager = {
		lib,
		pkgs,
		...
	}: {
		home.packages = with pkgs; [
			vivid
		];

		programs.nushell = {
			enable = true;

			settings = {
				show_banner = false;
				edit_mode = "vi";
				completions = {
					algorithm = "fuzzy";
					case_sensitive = false;
				};
				history = {
					file_format = "sqlite";
				};
			};

			environmentVariables = {
				COLORTERM = "truecolor";
				COLORFGBG = "15;0";
				TERM_BACKGROUND = "light";
				EDITOR = "nvim";
			};

			extraEnv =
				''
					$env.LS_COLORS = (${pkgs.vivid}/bin/vivid generate ${theme.slug})
				''
				+ lib.optionalString pkgs.stdenv.isDarwin ''
					# Nushell on Darwin doesn't source /etc/zprofile or path_helper,
					# so nix-managed paths must be added explicitly.
					$env.PATH = ($env.PATH | split row (char esep) | prepend "/run/current-system/sw/bin" | prepend $"($env.HOME)/.nix-profile/bin")
				'';

			extraConfig = ''
				# --- Rosé Pine Dawn Theme ---
				let theme = {
					love: "${palette.love}"
					gold: "${palette.gold}"
					rose: "${palette.rose}"
					pine: "${palette.pine}"
					foam: "${palette.foam}"
					iris: "${palette.iris}"
					leaf: "${palette.leaf}"
					text: "${palette.text}"
					subtle: "${palette.subtle}"
					muted: "${palette.muted}"
					highlight_high: "${palette.highlightHigh}"
					highlight_med: "${palette.highlightMed}"
					highlight_low: "${palette.highlightLow}"
					overlay: "${palette.overlay}"
					surface: "${palette.surface}"
					base: "${palette.base}"
				}

				let scheme = {
					recognized_command: $theme.pine
					unrecognized_command: $theme.text
					constant: $theme.gold
					punctuation: $theme.muted
					operator: $theme.subtle
					string: $theme.gold
					virtual_text: $theme.highlight_high
					variable: { fg: $theme.rose attr: i }
					filepath: $theme.iris
				}

				$env.config.color_config = {
					separator: { fg: $theme.highlight_high attr: b }
					leading_trailing_space_bg: { fg: $theme.iris attr: u }
					header: { fg: $theme.text attr: b }
					row_index: $scheme.virtual_text
					record: $theme.text
					list: $theme.text
					hints: $scheme.virtual_text
					search_result: { fg: $theme.base bg: $theme.gold }
					shape_closure: $theme.foam
					closure: $theme.foam
					shape_flag: { fg: $theme.love attr: i }
					shape_matching_brackets: { attr: u }
					shape_garbage: $theme.love
					shape_keyword: $theme.iris
					shape_match_pattern: $theme.leaf
					shape_signature: $theme.foam
					shape_table: $scheme.punctuation
					cell-path: $scheme.punctuation
					shape_list: $scheme.punctuation
					shape_record: $scheme.punctuation
					shape_vardecl: $scheme.variable
					shape_variable: $scheme.variable
					empty: { attr: n }
					filesize: {||
						if $in < 1kb {
							$theme.foam
						} else if $in < 10kb {
							$theme.leaf
						} else if $in < 100kb {
							$theme.gold
						} else if $in < 10mb {
							$theme.rose
						} else if $in < 100mb {
							$theme.love
						} else if $in < 1gb {
							$theme.love
						} else {
							$theme.iris
						}
					}
					duration: {||
						if $in < 1day {
							$theme.foam
						} else if $in < 1wk {
							$theme.leaf
						} else if $in < 4wk {
							$theme.gold
						} else if $in < 12wk {
							$theme.rose
						} else if $in < 24wk {
							$theme.love
						} else if $in < 52wk {
							$theme.love
						} else {
							$theme.iris
						}
					}
					datetime: {|| (date now) - $in |
						if $in < 1day {
							$theme.foam
						} else if $in < 1wk {
							$theme.leaf
						} else if $in < 4wk {
							$theme.gold
						} else if $in < 12wk {
							$theme.rose
						} else if $in < 24wk {
							$theme.love
						} else if $in < 52wk {
							$theme.love
						} else {
							$theme.iris
						}
					}
					shape_external: $scheme.unrecognized_command
					shape_internalcall: $scheme.recognized_command
					shape_external_resolved: $scheme.recognized_command
					shape_block: $scheme.recognized_command
					block: $scheme.recognized_command
					shape_custom: $theme.rose
					custom: $theme.rose
					background: $theme.base
					foreground: $theme.text
					cursor: { bg: $theme.text fg: $theme.base }
					shape_range: $scheme.operator
					range: $scheme.operator
					shape_pipe: $scheme.operator
					shape_operator: $scheme.operator
					shape_redirection: $scheme.operator
					glob: $scheme.filepath
					shape_directory: $scheme.filepath
					shape_filepath: $scheme.filepath
					shape_glob_interpolation: $scheme.filepath
					shape_globpattern: $scheme.filepath
					shape_int: $scheme.constant
					int: $scheme.constant
					bool: $scheme.constant
					float: $scheme.constant
					nothing: $scheme.constant
					binary: $scheme.constant
					shape_nothing: $scheme.constant
					shape_bool: $scheme.constant
					shape_float: $scheme.constant
					shape_binary: $scheme.constant
					shape_datetime: $scheme.constant
					shape_literal: $scheme.constant
					string: $scheme.string
					shape_string: $scheme.string
					shape_string_interpolation: $theme.rose
					shape_raw_string: $scheme.string
					shape_externalarg: $scheme.string
				}
				$env.config.highlight_resolved_externals = true
				$env.config.explore = {
					status_bar_background: { fg: $theme.text, bg: $theme.surface },
					command_bar_text: { fg: $theme.text },
					highlight: { fg: $theme.base, bg: $theme.gold },
					status: {
						error: $theme.love,
						warn: $theme.gold,
						info: $theme.pine,
					},
					selected_cell: { bg: $theme.pine fg: $theme.base },
				}

					# --- Custom Commands ---
					def --env open_project [] {
						let base = ($env.HOME | path join "Projects")
						let choice = (
							${pkgs.fd}/bin/fd -t d -d 1 -a . ($base | path join "Personal") ($base | path join "Work")
							| lines
							| each {|p| $p | str replace $"($base)/" "" }
							| str join "\n"
							| ${pkgs.fzf}/bin/fzf --prompt "project > "
						)
						if ($choice | str trim | is-not-empty) {
							cd ($base | path join ($choice | str trim))
						}
					}

					# --- Keybinding: Ctrl+O for open_project ---
					$env.config.keybindings = ($env.config.keybindings | append [
						{
							name: open_project
							modifier: control
							keycode: char_o
							mode: [emacs vi_insert vi_normal]
							event: {
								send: executehostcommand
								cmd: "open_project"
							}
						}
				])

				# Vi mode indicators — Starship handles the character (green/red for
				# success/error), nushell adds a dot for normal mode.
				$env.PROMPT_INDICATOR_VI_INSERT = "· "
				$env.PROMPT_INDICATOR_VI_NORMAL = "\e[1;38;2;${pineAnsi}m·\e[0m "
			'';
		};

		programs.zsh = {
			enable = true;
		};

		programs.starship = {
			enable = true;
			enableNushellIntegration = true;
			settings = {
				format = "$directory\${custom.scm}$hostname$line_break$character";
				buf = {
					disabled = true;
				};
				character = {
					error_symbol = "[󰘧](bold red)";
					success_symbol = "[󰘧](bold green)";
				};
				directory = {
					truncate_to_repo = false;
				};
				git_branch = {
					disabled = true;
					symbol = " ";
					truncation_length = 18;
				};
				git_status = {
					disabled = true;
				};
				git_commit = {
					disabled = true;
				};
				git_state = {
					disabled = true;
				};
				custom.scm = {
					when = "jj-starship detect";
					shell = ["jj-starship" "--strip-bookmark-prefix" "${local.user.name}/" "--truncate-name" "20" "--bookmarks-display-limit" "1"];
					format = "$output ";
				};
				lua = {
					symbol = " ";
				};
				package = {
					disabled = true;
				};
			};
		};
	};
}
