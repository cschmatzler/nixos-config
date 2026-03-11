{pkgs, ...}: {
	programs.nixvim = {
		plugins.treesitter = {
			enable = true;
			nixGrammars = true;
			grammarPackages = pkgs.vimPlugins.nvim-treesitter.allGrammars;
			settings = {
				highlight.enable = true;
				indent.enable = true;
			};
		};

		# Register missing treesitter predicates for compatibility with newer grammars
		extraConfigLuaPre = ''
			do
				local query = require("vim.treesitter.query")
				local predicates = query.list_predicates()
				if not vim.tbl_contains(predicates, "is-not?") then
					query.add_predicate("is-not?", function(match, pattern, source, predicate)
						local dominated_by = predicate[2]
						local dominated = false
						for _, node in pairs(match) do
							if type(node) == "userdata" then
								local current = node:parent()
								while current do
									if current:type() == dominated_by then
										dominated = true
										break
									end
									current = current:parent()
								end
							end
						end
						return not dominated
					end, { force = true, all = true })
				end
			end

			-- Fix grammar-bundled treesitter queries that use #match? with Lua pattern
			-- syntax (e.g. %d) instead of Vim regex. Neovim 0.11 picks the first
			-- non-extending query file in the rtp as the base, so the grammar-bundled
			-- (buggy) queries take precedence over the corrected site-level queries.
			-- Override affected languages with the site-level version.
			do
				local langs = { "sql" }
				for _, lang in ipairs(langs) do
					local files = vim.api.nvim_get_runtime_file(
						"queries/" .. lang .. "/highlights.scm", true)
					if #files > 1 then
						local f = io.open(files[#files])
						if f then
							vim.treesitter.query.set(lang, "highlights", f:read("*all"))
							f:close()
						end
					end
				end
			end
		'';
	};
}
