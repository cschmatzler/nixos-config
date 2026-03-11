{pkgs, ...}: let
	opencode-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "opencode-nvim";
			version = "unstable-2026-03-07";
			src =
				pkgs.fetchFromGitHub {
					owner = "sudo-tee";
					repo = "opencode.nvim";
					rev = "dffa3f39a8251c7ba53b1544d8536b5f51b4e90d";
					hash = "sha256-KxIuToMpyo/Yi4xKirMV8Fznlma6EL1k4YQm5MQdGw4=";
				};
			doCheck = false;
		};
in {
	programs.nixvim = {
		extraPlugins = with pkgs.vimPlugins; [
			opencode-nvim
			plenary-nvim
			render-markdown-nvim
		];
		extraConfigLua = ''
			local api = vim.api
			local opencode_output_filetype = 'opencode_output'
			local opencode_window_filetypes = {
				opencode = true,
				opencode_output = true,
			}

			local palette = {
				base = '#eff1f5',
				mantle = '#e6e9ef',
				surface0 = '#ccd0da',
				surface1 = '#bcc0cc',
				text = '#4c4f69',
				subtext0 = '#6c6f85',
				overlay0 = '#9ca0b0',
				blue = '#1e66f5',
				lavender = '#7287fd',
				sapphire = '#209fb5',
				teal = '#179299',
				green = '#40a02b',
				mauve = '#8839ef',
				peach = '#fe640b',
			}

			local function set_highlights(highlights)
				for group, spec in pairs(highlights) do
					api.nvim_set_hl(0, group, spec)
				end
			end

			local opencode_markdown_conceal_query = vim.treesitter.query.parse('markdown_inline', [[
				[
					(emphasis_delimiter)
					(code_span_delimiter)
					(latex_span_delimiter)
				] @conceal

				(inline_link
					[
						"["
						"]"
						"("
						(link_destination)
						")"
					] @conceal)

				(full_reference_link
					[
						"["
						"]"
						(link_label)
					] @conceal)

				(collapsed_reference_link
					[
						"["
						"]"
					] @conceal)

				(shortcut_link
					[
						"["
						"]"
					] @conceal)

				(image
					[
						"!"
						"["
						"]"
						"("
						(link_destination)
						")"
					] @conceal)
			]])

			local function collect_conceal_marks(ctx)
				local marks = {}

				for _, node in opencode_markdown_conceal_query:iter_captures(ctx.root, ctx.buf) do
					local start_row, start_col, end_row, end_col = node:range()
					marks[#marks + 1] = {
						conceal = true,
						start_row = start_row,
						start_col = start_col,
						opts = {
							end_row = end_row,
							end_col = end_col,
							conceal = "",
						},
					}
				end

				return marks
			end

			local function set_opencode_output_conceal()
				if vim.bo.filetype ~= opencode_output_filetype then
					return
				end

				vim.wo.conceallevel = 3
				vim.wo.concealcursor = 'nvic'
			end

			local function hide_opencode_statusline()
				if not opencode_window_filetypes[vim.bo.filetype] then
					return
				end

				vim.wo.statusline = ' '
			end

			vim.treesitter.language.register('markdown', opencode_output_filetype)
			vim.treesitter.language.register('markdown_inline', opencode_output_filetype)

			api.nvim_create_autocmd({ 'FileType', 'BufWinEnter', 'WinEnter' }, {
				callback = set_opencode_output_conceal,
			})
			api.nvim_create_autocmd({ 'FileType', 'BufWinEnter', 'WinEnter', 'BufEnter' }, {
				pattern = '*',
				callback = hide_opencode_statusline,
			})

			set_highlights({
				RenderMarkdownCode = { bg = palette.mantle },
				RenderMarkdownCodeBorder = { fg = palette.surface0, bg = palette.mantle },
				RenderMarkdownCodeInline = { bg = palette.mantle },
				RenderMarkdownH1 = { fg = palette.blue, bold = true },
				RenderMarkdownH2 = { fg = palette.mauve, bold = true },
				RenderMarkdownH3 = { fg = palette.teal, bold = true },
				RenderMarkdownH4 = { fg = palette.peach, bold = true },
				OpencodeInputLegend = { fg = palette.subtext0, bold = true },
				OpencodeAgentBuild = { bg = palette.overlay0, fg = palette.base, bold = true },
			})

			local render_markdown_config = {
				anti_conceal = { enabled = false },
				heading = {
					icons = { '◆ ', '◇ ', '○ ', '· ', '· ', '· ' },
					backgrounds = {},
					position = 'inline',
					width = 'block',
					left_pad = 0,
					right_pad = 2,
					border = false,
					sign = false,
				},
				code = {
					sign = false,
					width = 'full',
					left_pad = 2,
					right_pad = 0,
					border = 'thin',
					language_icon = false,
					language_name = true,
				},
				bullet = {
					icons = { '·', '–', '·', '–' },
				},
				custom_handlers = {
					markdown_inline = {
						extends = true,
						parse = collect_conceal_marks,
					},
				},
				file_types = { opencode_output_filetype },
				win_options = {
					conceallevel = { rendered = 3 },
					concealcursor = { rendered = 'nvic' },
				},
			}

			require('render-markdown').setup(render_markdown_config)

			local opencode_icon_overrides = {
				header_user = '│',
				header_assistant = '│',
				run = '▸',
				task = '◦',
				read = '◦',
				edit = '◦',
				write = '◦',
				plan = '◦',
				search = '◦',
				web = '◦',
				list = '◦',
				tool = '◦',
				snapshot = '◦',
				restore_point = '◦',
				file = '·',
				folder = '·',
				attached_file = '·',
				agent = '·',
				reference = '·',
				reasoning = '◦',
				question = '?',
				border = '│',
			}

			require('opencode').setup({
				server = {
					url = 'http://127.0.0.1',
					port = 18822,
					auto_kill = false,
				},
				input = {
					text = {
						wrap = true,
					},
				},
				debug = {
					show_ids = false,
				},
				ui = {
					icons = {
						preset = 'nerdfonts',
						overrides = opencode_icon_overrides,
					},
				},
			})

			do
				local config = require('opencode.config')
				local formatter = require('opencode.ui.formatter')
				local format_utils = require('opencode.ui.formatter.utils')
				local icons = require('opencode.ui.icons')
				local util = require('opencode.util')

				local function format_reasoning_title(part)
					local title = 'Reasoning'
					local time = part.time

					if time and type(time) == 'table' and time.start then
						local duration_text = util.format_duration_seconds(time.start, time['end'])
						if duration_text then
							title = string.format('%s %s', title, duration_text)
						end
					end

					return title
				end

				local function highlight_reasoning_block(output, start_line)
					local end_line = output:get_line_count()

					if end_line - start_line > 1 then
						formatter.add_vertical_border(output, start_line, end_line, 'OpencodeToolBorder', -1, 'OpencodeReasoningText')
						return
					end

					output:add_extmark(start_line - 1, {
						line_hl_group = 'OpencodeReasoningText',
					})
				end

				formatter._format_reasoning = function(output, part)
					local text = vim.trim(part.text or "")
					local start_line = output:get_line_count() + 1

					format_utils.format_action(output, icons.get('reasoning'), format_reasoning_title(part), "")

					if config.ui.output.tools.show_reasoning_output and text ~= "" then
						output:add_empty_line()
						output:add_lines(vim.split(text, '\n'), '  ')
						output:add_empty_line()
					end

					highlight_reasoning_block(output, start_line)
				end
			end
		'';
	};
}
