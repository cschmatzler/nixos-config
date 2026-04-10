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
				comment = {};
				diff = {};
				extra = {};
				hipatterns = {
					highlighters = {
						fixme.__raw = "{ pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' }";
						hack.__raw = "{ pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' }";
						todo.__raw = "{ pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' }";
						note.__raw = "{ pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' }";
						hex_color.__raw = "require('mini.hipatterns').gen_highlighter.hex_color()";
					};
				};
				jump = {};
				move = {};
				pairs = {};
				splitjoin = {};
				surround = {};
				trailspace = {};
			};
		};
	};
}
