{
	inputs',
	nvim-plugin-sources,
	pkgs,
	...
}: let
	opencode-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "opencode-nvim";
			version = "unstable";
			src = nvim-plugin-sources.opencode-nvim;
			doCheck = false;
		};
in {
	imports = [
		./autocmd.nix
		./mappings.nix
		./options.nix
		./plugins/blink-cmp.nix
		./plugins/code-review.nix
		./plugins/conform.nix
		./plugins/diffview.nix
		./plugins/grug-far.nix
		./plugins/hardtime.nix
		./plugins/harpoon.nix
		./plugins/hunk.nix
		./plugins/jj-diffconflicts.nix
		./plugins/jj-nvim.nix
		./plugins/lsp.nix
		./plugins/mini.nix
		./plugins/oil.nix
		./plugins/opencode-review.nix
		./plugins/render-markdown.nix
		./plugins/toggleterm.nix
		./plugins/treesitter.nix
		./plugins/zk.nix
	];

	programs.nixvim = {
		enable = true;
		defaultEditor = true;
		package = inputs'.neovim-nightly-overlay.packages.default;
		luaLoader.enable = true;
		extraPlugins = [
			opencode-nvim
		];
		extraConfigLua = ''
			local function clear_winbar(win)
				if win and vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_set_option_value('winbar', "", { win = win })
				end
			end

			local function disable_statusline(buf)
				if buf and vim.api.nvim_buf_is_valid(buf) then
					vim.b[buf].ministatusline_disable = true
				end
			end

			require('opencode').setup({
				debug = {
					show_ids = false,
				},
			})

			do
				local state = require('opencode.state')
				local context_bar = require('opencode.ui.context_bar')
				local input_window = require('opencode.ui.input_window')
				local output_window = require('opencode.ui.output_window')
				local topbar = require('opencode.ui.topbar')

				local input_setup = input_window.setup
				input_window.setup = function(windows)
					input_setup(windows)
					disable_statusline(windows and windows.input_buf)
					clear_winbar(windows and windows.input_win)
				end

				local output_setup = output_window.setup
				output_window.setup = function(windows)
					output_setup(windows)
					disable_statusline(windows and windows.output_buf)
					clear_winbar(windows and windows.output_win)
				end

				context_bar.render = function(windows)
					vim.schedule(function()
						windows = windows or state.windows
						clear_winbar(windows and windows.input_win)
					end)
				end

				topbar.render = function()
					vim.schedule(function()
						clear_winbar(state.windows and state.windows.output_win)
					end)
				end
			end

			vim.api.nvim_create_autocmd('FileType', {
				pattern = { 'opencode', 'opencode_output' },
				callback = function(args)
					disable_statusline(args.buf)
				end,
			})
		'';
		colorschemes.rose-pine = {
			enable = true;
			settings = {
				variant = "dawn";
				extend_background_behind_borders = false;
				styles = {
					italic = false;
				};
			};
		};
	};

	home.shellAliases = {
		v = "nvim";
	};
}
