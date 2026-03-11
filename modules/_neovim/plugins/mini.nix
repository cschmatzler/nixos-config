{
	programs.nixvim = {
		plugins.mini = {
			enable = true;
			modules = {
				ai = {
					custom_textobjects = {
						B.__raw = "require('mini.extra').gen_ai_spec.buffer()";
						F.__raw = "require('mini.ai').gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' })";
					};
				};
				align = {};
				basics = {
					options = {
						basic = true;
						extra_ui = true;
					};
					mappings = {
						basic = false;
					};
					autocommands = {
						basic = true;
					};
				};
				bracketed = {};
				clue = {
					clues.__raw = ''
						{
						  { mode = 'n', keys = '<Leader>e', desc = '+Explore/+Edit' },
						  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
						  { mode = 'n', keys = '<Leader>v', desc = '+VCS' },
						{ mode = 'n', keys = '<Leader>l', desc = '+LSP' },
						{ mode = 'x', keys = '<Leader>l', desc = '+LSP' },
						{ mode = 'n', keys = '<Leader>o', desc = '+OpenCode' },
						{ mode = 'x', keys = '<Leader>o', desc = '+OpenCode' },
						{ mode = 'n', keys = '<Leader>r', desc = '+Review' },
						{ mode = 'v', keys = '<Leader>r', desc = '+Review' },
						  require("mini.clue").gen_clues.builtin_completion(),
						  require("mini.clue").gen_clues.g(),
						  require("mini.clue").gen_clues.marks(),
						  require("mini.clue").gen_clues.registers(),
						  require("mini.clue").gen_clues.windows({ submode_resize = true }),
						  require("mini.clue").gen_clues.z(),
						}
					'';
					triggers = [
						{
							mode = "n";
							keys = "<Leader>";
						}
						{
							mode = "x";
							keys = "<Leader>";
						}
						{
							mode = "n";
							keys = "[";
						}
						{
							mode = "n";
							keys = "]";
						}
						{
							mode = "x";
							keys = "[";
						}
						{
							mode = "x";
							keys = "]";
						}
						{
							mode = "i";
							keys = "<C-x>";
						}
						{
							mode = "n";
							keys = "g";
						}
						{
							mode = "x";
							keys = "g";
						}

						{
							mode = "n";
							keys = "\"";
						}
						{
							mode = "x";
							keys = "\"";
						}
						{
							mode = "i";
							keys = "<C-r>";
						}
						{
							mode = "c";
							keys = "<C-r>";
						}
						{
							mode = "n";
							keys = "<C-w>";
						}
						{
							mode = "n";
							keys = "z";
						}
						{
							mode = "x";
							keys = "z";
						}
						{
							mode = "n";
							keys = "'";
						}
						{
							mode = "n";
							keys = "`";
						}
						{
							mode = "x";
							keys = "'";
						}
						{
							mode = "x";
							keys = "`";
						}
					];
				};
				cmdline = {};
				comment = {};
				diff = {};
				extra = {};
				git = {};
				hipatterns = {
					highlighters = {
						fixme.__raw = "{ pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' }";
						hack.__raw = "{ pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' }";
						todo.__raw = "{ pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' }";
						note.__raw = "{ pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' }";
						hex_color.__raw = "require('mini.hipatterns').gen_highlighter.hex_color()";
					};
				};
				icons = {};
				indentscope = {
					settings = {
						symbol = "|";
					};
				};
				jump = {};
				jump2d = {
					settings = {
						spotter.__raw = "require('mini.jump2d').gen_spotter.pattern('[^%s%p]+')";
						labels = "asdfghjkl";
						view = {
							dim = true;
							n_steps_ahead = 2;
						};
					};
				};
				move = {};
				notify = {
					content.format.__raw = ''
						function(notif)
							local formatted = MiniNotify.default_format(notif)
							return '\n   ' .. formatted:gsub('\n', '   \n   ') .. '   \n'
						end
					'';
					window.config = {
						border = "none";
						title = "";
					};
				};
				pairs = {};
				pick = {};
				splitjoin = {};
				starter = {};
				statusline = {
					content.active.__raw = ''
						function()
							local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
							local diff = MiniStatusline.section_diff({ trunc_width = 75 })
							local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
							local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
							local filename = MiniStatusline.section_filename({ trunc_width = 140 })
							local search = MiniStatusline.section_searchcount({ trunc_width = 75 })

							return _G.CschStatusline.active({
								mode = mode,
								mode_hl = mode_hl,
								diff = diff,
								diagnostics = diagnostics,
								lsp = lsp,
								filename = filename,
								search = search,
							})
						end
					'';
				};
				surround = {};
				trailspace = {};
				visits = {};
			};
			mockDevIcons = true;
		};

		extraConfigLua = ''
			local mini_notify_group = vim.api.nvim_create_augroup('MiniNotifyDesign', { clear = true })
			_G.CschStatusline = _G.CschStatusline or {}

			local function to_hex(value)
				return value and string.format('#%06x', value) or nil
			end

			local function get_hl(name)
				return vim.api.nvim_get_hl(0, { name = name, link = false })
			end

			local function get_fg(name, fallback)
				return to_hex(get_hl(name).fg) or fallback
			end

			local function get_bg(name, fallback)
				return to_hex(get_hl(name).bg) or fallback
			end

			local function set_statusline_highlights()
				local block_bg = get_bg('CursorLine', get_bg('Visual', '#373b41'))
				local block_fg = get_fg('StatusLine', get_fg('Normal', '#c5c8c6'))

				vim.api.nvim_set_hl(0, 'CschStatuslineBlock', { fg = block_fg, bg = block_bg })
			end

			local function statusline_group(hl, strings)
				local parts = vim.tbl_filter(function(x)
					return type(x) == 'string' and x ~= ""
				end, strings or {})

				if #parts == 0 then
					return ""
				end

				return string.format('%%#%s# %s ', hl, table.concat(parts, ' '))
			end

			local function statusline_block(text, hl)
				if text == nil or text == "" then
					return ""
				end

				return string.format('%%#%s# %s ', hl, text)
			end

			local function statusline_filesize()
				local size = math.max(vim.fn.line2byte(vim.fn.line('$') + 1) - 1, 0)

				if size < 1024 then
					return string.format('%dB', size)
				elseif size < 1048576 then
					return string.format('%.2fKiB', size / 1024)
				end

				return string.format('%.2fMiB', size / 1048576)
			end

			local function statusline_filetype()
				local filetype = vim.bo.filetype

				if filetype == "" then
					return vim.bo.buftype ~= "" and vim.bo.buftype or 'text'
				end

				local icon = ""
				if _G.MiniIcons ~= nil then
					icon = _G.MiniIcons.get('filetype', filetype) or ""
				end

				return (icon ~= "" and (icon .. ' ') or "") .. filetype
			end

			local function statusline_fileinfo()
				local label = statusline_filetype()

				if MiniStatusline.is_truncated(120) or vim.bo.buftype ~= "" then
					return label
				end

				return string.format('%s · %s', label, statusline_filesize())
			end

			local function statusline_location()
				local line = vim.fn.line('.')
				local total_lines = vim.fn.line('$')
				local column = vim.fn.virtcol('.')

				if MiniStatusline.is_truncated(90) then
					return string.format('Ln %d Col %d', line, column)
				end

				return string.format('Ln %d/%d · Col %d', line, total_lines, column)
			end

			function _G.CschStatusline.active(parts)
				local left = vim.tbl_filter(function(x)
					return x ~= ""
				end, {
					statusline_block(parts.mode, parts.mode_hl),
					statusline_group('MiniStatuslineDevinfo', { parts.diff, parts.diagnostics, parts.lsp }),
					'%<',
					statusline_group('MiniStatuslineFilename', { parts.filename }),
				})
				local right = vim.tbl_filter(function(x)
					return x ~= ""
				end, {
					statusline_block(statusline_fileinfo(), 'CschStatuslineBlock'),
					statusline_block(parts.search, 'CschStatuslineBlock'),
					statusline_block(statusline_location(), parts.mode_hl),
				})

				return table.concat(left, "") .. '%=%#StatusLine#' .. table.concat(right, "")
			end

			local function set_mini_notify_highlights()
				local border = vim.api.nvim_get_hl(0, { name = 'FloatBorder' })
				local normal = vim.api.nvim_get_hl(0, { name = 'NormalFloat' })
				local popup_bg = get_bg('Pmenu', get_bg('CursorLine', get_bg('NormalFloat', '#303446')))
				local title = vim.api.nvim_get_hl(0, { name = 'FloatTitle' })

				border.bg = 'NONE'
				normal.bg = popup_bg
				normal.bold = true
				title.bg = 'NONE'

				vim.api.nvim_set_hl(0, 'MiniNotifyBorder', border)
				vim.api.nvim_set_hl(0, 'MiniNotifyNormal', normal)
				vim.api.nvim_set_hl(0, 'MiniNotifyTitle', title)
			end

			vim.api.nvim_create_autocmd('ColorScheme', {
				group = mini_notify_group,
				callback = function()
					set_mini_notify_highlights()
					set_statusline_highlights()
				end,
			})

			set_mini_notify_highlights()
			set_statusline_highlights()
		'';
	};
}
