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
							{ mode = 'n', keys = '<Leader>t', desc = '+Tab' },
							{ mode = 'n', keys = '<Leader>w', desc = '+Window' },
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
				notify = {};
				pairs = {};
				pick = {};
				splitjoin = {};
				starter = {};
				statusline = {};
				surround = {};
				trailspace = {};
				visits = {};
			};
			mockDevIcons = true;
		};
	};
}
