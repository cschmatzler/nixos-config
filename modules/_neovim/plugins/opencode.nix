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

			local function set_opencode_output_conceal()
				if vim.bo.filetype ~= 'opencode_output' then
					return
				end

				vim.wo.conceallevel = 3
				vim.wo.concealcursor = 'nvic'
			end

			vim.treesitter.language.register('markdown', 'opencode_output')
			vim.treesitter.language.register('markdown_inline', 'opencode_output')

			vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter', 'WinEnter' }, {
				callback = set_opencode_output_conceal,
			})

			require('render-markdown').setup({
				anti_conceal = { enabled = false },
				custom_handlers = {
					markdown_inline = {
						extends = true,
						parse = function(ctx)
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
						end,
					},
				},
				file_types = { 'opencode_output' },
				win_options = {
					conceallevel = { rendered = 3 },
					concealcursor = { rendered = "nvic" },
				},
			})
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
					ui = {
						icons = {
							preset = 'nerdfonts',
						},
						questions = {
							use_vim_ui_select = true,
						},
					},
				})

				do
					local config = require('opencode.config')
					local formatter = require('opencode.ui.formatter')
					local format_utils = require('opencode.ui.formatter.utils')
					local icons = require('opencode.ui.icons')
					local util = require('opencode.util')

					formatter._format_reasoning = function(output, part)
						local text = vim.trim(part.text or "")
						local start_line = output:get_line_count() + 1

						local title = 'Reasoning'
						local time = part.time
						if time and type(time) == 'table' and time.start then
							local duration_text = util.format_duration_seconds(time.start, time['end'])
							if duration_text then
								title = string.format('%s %s', title, duration_text)
							end
						end

						format_utils.format_action(output, icons.get('reasoning'), title, "")

						if config.ui.output.tools.show_reasoning_output and text ~= "" then
							output:add_empty_line()
							output:add_lines(vim.split(text, '\n'), '  ')
							output:add_empty_line()
						end

						local end_line = output:get_line_count()
						if end_line - start_line > 1 then
							formatter.add_vertical_border(output, start_line, end_line, 'OpencodeToolBorder', -1, 'OpencodeReasoningText')
						else
							output:add_extmark(start_line - 1, {
								line_hl_group = 'OpencodeReasoningText',
							})
						end
					end
				end
		'';
	};
}
