{
	programs.nixvim.keymaps = [
		# clipboard - OSC52 yank and paste
		{
			mode = ["n" "v"];
			key = "<leader>y";
			action = ''"+y'';
			options.desc = "Yank to system clipboard (OSC52)";
		}
		# e - explore/edit
		{
			mode = "n";
			key = "<leader>ef";
			action = ":lua require('oil').open()<CR>";
			options.desc = "File directory";
		}
		{
			mode = "n";
			key = "<leader>er";
			action = ":lua require('grug-far').open()<CR>";
			options.desc = "Search and replace";
		}
		# f - find
		{
			mode = "n";
			key = "<leader>f/";
			action = ":Pick history scope='/'<CR>";
			options.desc = "'/' history";
		}
		{
			mode = "n";
			key = "<leader>f:";
			action = ":Pick history scope=':'<CR>";
			options.desc = "':' history";
		}
		{
			mode = "n";
			key = "<leader>fa";
			action = ":Pick git_hunks scope='staged'<CR>";
			options.desc = "Added hunks (all)";
		}
		{
			mode = "n";
			key = "<leader>fA";
			action = ":Pick git_hunks path='%' scope='staged'<CR>";
			options.desc = "Added hunks (buffer)";
		}
		{
			mode = "n";
			key = "<leader>fb";
			action = ":Pick buffers<CR>";
			options.desc = "Buffers";
		}
		{
			mode = "n";
			key = "<leader>fd";
			action = ":Pick diagnostic scope='all'<CR>";
			options.desc = "Diagnostic (workspace)";
		}
		{
			mode = "n";
			key = "<leader>fD";
			action = ":Pick diagnostic scope='current'<CR>";
			options.desc = "Diagnostic (buffer)";
		}
		{
			mode = "n";
			key = "<leader>ff";
			action = ":Pick files<CR>";
			options.desc = "Search files";
		}
		{
			mode = "n";
			key = "<leader>fg";
			action = ":Pick grep_live<CR>";
			options.desc = "Grep";
		}
		{
			mode = "n";
			key = "<leader>fm";
			action = ":Pick git_hunks<CR>";
			options.desc = "Modified hunks (all)";
		}
		{
			mode = "n";
			key = "<leader>fM";
			action = ":Pick git_hunks path='%'<CR>";
			options.desc = "Modified hunks (buffer)";
		}
		{
			mode = "n";
			key = "<leader>fr";
			action = ":Pick lsp scope='references'<CR>";
			options.desc = "References (LSP)";
		}
		{
			mode = "n";
			key = "<leader>fs";
			action = ":Pick lsp scope='workspace_symbol'<CR>";
			options.desc = "Symbols (LSP, workspace)";
		}
		{
			mode = "n";
			key = "<leader>fS";
			action = ":Pick lsp scope='document_symbol'<CR>";
			options.desc = "Symbols (LSP, buffer)";
		}
		{
			mode = "n";
			key = "<leader>fv";
			action = ":Pick visit_paths cwd=\"\"<CR>";
			options.desc = "Visit paths (all)";
		}
		{
			mode = "n";
			key = "<leader>fV";
			action = ":Pick visit_paths<CR>";
			options.desc = "Visit paths (cwd)";
		}
		# v - vcs
		{
			mode = "n";
			key = "<leader>va";
			action = ":J annotate<CR>";
			options.desc = "Annotate (blame)";
		}
		{
			mode = "n";
			key = "<leader>vc";
			action = ":JJDiffConflicts<CR>";
			options.desc = "Resolve conflicts";
		}
		{
			mode = "n";
			key = "<leader>vd";
			action.__raw = ''
				function()
					require('jj.cmd').diff()
				end
			'';
			options.desc = "Diff (current file)";
		}
		{
			mode = "n";
			key = "<leader>vD";
			action.__raw = ''
				function()
					require('jj.diff').show_revision({})
				end
			'';
			options.desc = "Diff (all changes)";
		}
		{
			mode = "n";
			key = "<leader>ve";
			action.__raw = ''
				function()
					require('jj.cmd').describe()
				end
			'';
			options.desc = "Describe (edit message)";
		}
		{
			mode = "n";
			key = "<leader>vf";
			action = ":J fetch<CR>";
			options.desc = "Fetch";
		}
		{
			mode = "n";
			key = "<leader>vv";
			action.__raw = ''
				function()
					require('toggleterm.terminal').Terminal:new({ cmd = 'jjui', direction = 'float' }):toggle()
				end
			'';
			options.desc = "jjui";
		}
		{
			mode = "n";
			key = "<leader>vh";
			action.__raw = ''
				function()
					require('jj.diff').show_revision({ rev = '@-' })
				end
			'';
			options.desc = "Diff parent revision";
		}
		{
			mode = "n";
			key = "<leader>vl";
			action.__raw = ''
				function()
					require('jj.cmd').log()
				end
			'';
			options.desc = "Log";
		}
		{
			mode = "n";
			key = "<leader>vn";
			action.__raw = ''
				function()
					require('jj.cmd').new()
				end
			'';
			options.desc = "New change";
		}
		{
			mode = "n";
			key = "<leader>vp";
			action = ":J git push<CR>";
			options.desc = "Push";
		}
		{
			mode = "n";
			key = "<leader>vq";
			action = ":DiffviewClose<CR>";
			options.desc = "Close diffview";
		}
		{
			mode = "n";
			key = "<leader>vR";
			action.__raw = ''
				function()
					require('jj.diff').diff_revisions({ left = 'trunk()', right = '@' })
				end
			'';
			options.desc = "Review bookmark (trunk..@)";
		}
		{
			mode = "n";
			key = "<leader>vs";
			action.__raw = ''
				function()
					require('jj.cmd').status()
				end
			'';
			options.desc = "Status";
		}
		# r - review
		{
			mode = ["n" "v"];
			key = "<leader>rc";
			action = ":CodeReviewComment<CR>";
			options.desc = "Add comment";
		}
		{
			mode = "n";
			key = "<leader>oR";
			action = ":OpencodeReview<CR>";
			options.desc = "Review with Opencode";
		}
		{
			mode = "n";
			key = "<leader>rd";
			action = ":CodeReviewDeleteComment<CR>";
			options.desc = "Delete comment";
		}
		{
			mode = "n";
			key = "<leader>rl";
			action = ":CodeReviewList<CR>";
			options.desc = "List comments";
		}
		{
			mode = "n";
			key = "<leader>ro";
			action = ":CodeReviewResolve<CR>";
			options.desc = "Resolve thread";
		}
		{
			mode = "n";
			key = "<leader>rp";
			action = ":CodeReviewPreview<CR>";
			options.desc = "Preview review";
		}
		{
			mode = "n";
			key = "<leader>rr";
			action = ":CodeReviewReply<CR>";
			options.desc = "Reply to comment";
		}
		{
			mode = "n";
			key = "<leader>rs";
			action = ":CodeReviewShowComment<CR>";
			options.desc = "Show comment";
		}
		{
			mode = "n";
			key = "<leader>rx";
			action = ":CodeReviewClear<CR>";
			options.desc = "Clear all comments";
		}
		{
			mode = "n";
			key = "<leader>ry";
			action = ":CodeReviewCopy<CR>";
			options.desc = "Copy review to clipboard";
		}
		# l - lsp/formatter
		{
			mode = "n";
			key = "<leader>la";
			action = ":lua vim.lsp.buf.code_action()<CR>";
			options.desc = "Actions";
		}
		{
			mode = "n";
			key = "<leader>ld";
			action = ":lua vim.diagnostic.open_float({ severity = { min = vim.diagnostic.severity.HINT } })<CR>";
			options.desc = "Diagnostics popup";
		}
		{
			mode = "n";
			key = "<leader>lf";
			action = ":lua require('conform').format({ lsp_fallback = true })<CR>";
			options.desc = "Format";
		}
		{
			mode = "n";
			key = "<leader>li";
			action = ":lua vim.lsp.buf.hover()<CR>";
			options.desc = "Information";
		}
		{
			mode = "n";
			key = "<leader>lj";
			action = ":lua vim.diagnostic.jump({ count = 1 })<CR>";
			options.desc = "Next diagnostic";
		}
		{
			mode = "n";
			key = "<leader>lk";
			action = ":lua vim.diagnostic.jump({ count = -1 })<CR>";
			options.desc = "Prev diagnostic";
		}
		{
			mode = "n";
			key = "<leader>lr";
			action = ":lua vim.lsp.buf.rename()<CR>";
			options.desc = "Rename";
		}
		{
			mode = "n";
			key = "<leader>lR";
			action = ":lua vim.lsp.buf.references()<CR>";
			options.desc = "References";
		}
		{
			mode = "n";
			key = "<leader>ls";
			action = ":lua vim.lsp.buf.definition()<CR>";
			options.desc = "Source definition";
		}
		# t - tab
		{
			mode = "n";
			key = "<leader>tc";
			action = ":tabclose<CR>";
			options.desc = "Close tab";
		}
		{
			mode = "n";
			key = "<leader>tn";
			action = ":tabnew<CR>";
			options.desc = "New tab";
		}
		{
			mode = "n";
			key = "<leader>to";
			action = ":tabonly<CR>";
			options.desc = "Close other tabs";
		}
		{
			mode = "n";
			key = "<leader>th";
			action = ":tabprevious<CR>";
			options.desc = "Previous tab";
		}
		{
			mode = "n";
			key = "<leader>tl";
			action = ":tabnext<CR>";
			options.desc = "Next tab";
		}
		# w - window
		{
			mode = "n";
			key = "<leader>wh";
			action = "<C-w>h";
			options.desc = "Go left";
		}
		{
			mode = "n";
			key = "<leader>wj";
			action = "<C-w>j";
			options.desc = "Go down";
		}
		{
			mode = "n";
			key = "<leader>wk";
			action = "<C-w>k";
			options.desc = "Go up";
		}
		{
			mode = "n";
			key = "<leader>wl";
			action = "<C-w>l";
			options.desc = "Go right";
		}
		{
			mode = "n";
			key = "<leader>ws";
			action = ":split<CR>";
			options.desc = "Split horizontal";
		}
		{
			mode = "n";
			key = "<leader>wv";
			action = ":vsplit<CR>";
			options.desc = "Split vertical";
		}
		{
			mode = "n";
			key = "<leader>wc";
			action = ":close<CR>";
			options.desc = "Close window";
		}
		{
			mode = "n";
			key = "<leader>wq";
			action = ":q<CR>";
			options.desc = "Quit window";
		}
		{
			mode = "n";
			key = "<leader>wo";
			action = ":only<CR>";
			options.desc = "Close other windows";
		}
		{
			mode = "n";
			key = "<leader>w=";
			action = "<C-w>=";
			options.desc = "Equalize windows";
		}
		# scrolling
		{
			mode = "n";
			key = "<C-d>";
			action = "<C-d>zz";
			options.desc = "Scroll down and center";
		}
		{
			mode = "n";
			key = "<C-u>";
			action = "<C-u>zz";
			options.desc = "Scroll up and center";
		}
		# other
		{
			mode = "n";
			key = "<leader>j";
			action = ":lua require('mini.jump2d').start(require('mini.jump2d').builtin_opts.query)<CR>";
			options.desc = "Jump to character";
		}
		{
			mode = "n";
			key = "<leader>a";
			action = ":lua require('harpoon'):list():add()<CR>";
			options.desc = "Add harpoon";
		}
		{
			mode = "n";
			key = "<C-e>";
			action = ":lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())<CR>";
			options.desc = "Toggle harpoon quick menu";
		}
		{
			mode = "n";
			key = "<leader>1";
			action = ":lua require('harpoon'):list():select(1)<CR>";
			options.desc = "Go to harpoon 1";
		}
		{
			mode = "n";
			key = "<leader>2";
			action = ":lua require('harpoon'):list():select(2)<CR>";
			options.desc = "Go to harpoon 2";
		}
		{
			mode = "n";
			key = "<leader>3";
			action = ":lua require('harpoon'):list():select(3)<CR>";
			options.desc = "Go to harpoon 3";
		}
		{
			mode = "n";
			key = "<leader>4";
			action = ":lua require('harpoon'):list():select(4)<CR>";
			options.desc = "Go to harpoon 4";
		}
		# z - zk (notes)
		{
			mode = "n";
			key = "<leader>zn";
			action = ":ZkNew { title = vim.fn.input('Title: ') }<CR>";
			options.desc = "New note";
		}
		{
			mode = "n";
			key = "<leader>zo";
			action = ":ZkNotes { sort = { 'modified' } }<CR>";
			options.desc = "Open notes";
		}
		{
			mode = "n";
			key = "<leader>zt";
			action = ":ZkTags<CR>";
			options.desc = "Browse tags";
		}
		{
			mode = "n";
			key = "<leader>zf";
			action = ":ZkNotes { sort = { 'modified' }, match = { vim.fn.input('Search: ') } }<CR>";
			options.desc = "Find notes";
		}
		{
			mode = "v";
			key = "<leader>zf";
			action = ":'<,'>ZkMatch<CR>";
			options.desc = "Find notes matching selection";
		}
		{
			mode = "n";
			key = "<leader>zb";
			action = ":ZkBacklinks<CR>";
			options.desc = "Backlinks";
		}
		{
			mode = "n";
			key = "<leader>zl";
			action = ":ZkLinks<CR>";
			options.desc = "Outbound links";
		}
		{
			mode = "n";
			key = "<leader>zi";
			action = ":ZkInsertLink<CR>";
			options.desc = "Insert link";
		}
		{
			mode = "v";
			key = "<leader>zi";
			action = ":'<,'>ZkInsertLinkAtSelection<CR>";
			options.desc = "Insert link at selection";
		}
		{
			mode = "v";
			key = "<leader>zc";
			action = ":'<,'>ZkNewFromTitleSelection<CR>";
			options.desc = "Create note from selection";
		}
	];
}
