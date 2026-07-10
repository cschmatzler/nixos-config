let
  keymap = mode: key: action: desc: {
    inherit mode key action;
    options = {inherit desc;};
  };
  normal = keymap "n";
  visual = keymap "v";
  normalVisual = keymap ["n" "v"];
  rawLua = __raw: {inherit __raw;};
  luaFunction = body: rawLua "function()\n  ${body}\nend\n";
  snacksPicker = call: luaFunction "Snacks.picker.${call}";
in {
  programs.nixvim.keymaps = [
    # clipboard - OSC52 yank and paste
    (normalVisual "<leader>y" ''"+y'' "Yank to system clipboard (OSC52)")

    # e - explore/edit
    (normal "<leader>ef" (luaFunction "require(\"oil\").open()") "Oil")
    (normal "<leader>er" ":lua require('grug-far').open()<CR>" "Search and replace")

    # f - find
    (normal "<leader>f/" (snacksPicker "search_history()") "Search history")
    (normal "<leader>f:" (snacksPicker "command_history()") "Command history")
    (normal "<leader>fa" (snacksPicker "git_diff({ staged = true })") "Staged hunks (all)")
    (normal "<leader>fA" (rawLua ''
      function()
        Snacks.picker.git_diff({
          staged = true,
          filter = { buf = true },
        })
      end
    '') "Staged hunks (buffer)")
    (normal "<leader>fb" (snacksPicker "buffers()") "Buffers")
    (normal "<leader>fd" (snacksPicker "diagnostics()") "Diagnostic (workspace)")
    (normal "<leader>fD" (snacksPicker "diagnostics_buffer()") "Diagnostic (buffer)")
    (normal "<leader>ff" (snacksPicker "files()") "Find files")
    (normal "<leader>fg" (snacksPicker "grep()") "Live grep")
    (normal "<leader>fm" (snacksPicker "git_diff()") "Modified hunks (all)")
    (normal "<leader>fM" (rawLua ''
      function()
        Snacks.picker.git_diff({
          filter = { buf = true },
        })
      end
    '') "Modified hunks (buffer)")
    (normal "<leader>fr" (snacksPicker "lsp_references()") "References (LSP)")
    (normal "<leader>fs" (snacksPicker "lsp_workspace_symbols()") "Symbols (LSP, workspace)")
    (normal "<leader>fS" (snacksPicker "lsp_symbols()") "Symbols (LSP, buffer)")
    (normal "<leader>fv" (snacksPicker "recent()") "Recent files (all)")
    (normal "<leader>fV" (rawLua ''
      function()
        Snacks.picker.recent({
          filter = { cwd = true },
        })
      end
    '') "Recent files (cwd)")

    # v - vcs
    (normal "<leader>va" ":vnew | terminal git blame -- %<CR>" "Annotate (blame)")
    (normal "<leader>vd" ":DiffviewOpen -- %<CR>" "Diff (current file)")
    (normal "<leader>vD" ":DiffviewOpen<CR>" "Diff (all changes)")
    (normal "<leader>ve" ":Neogit commit<CR>" "Commit")
    (normal "<leader>vf" ":!git fetch --all --prune<CR>" "Fetch")
    (normal "<leader>vv" ":Neogit<CR>" "Neogit")
    (normal "<leader>vh" ":DiffviewOpen HEAD~1..HEAD<CR>" "Diff parent revision")
    (normal "<leader>vl" ":Neogit log<CR>" "Log")
    (normal "<leader>vn" ":Neogit branch<CR>" "Branch")
    (normal "<leader>vp" ":!git push<CR>" "Push")
    (normal "<leader>vq" ":DiffviewClose<CR>" "Close diffview")
    (normal "<leader>vR" ":DiffviewOpen origin/HEAD...HEAD<CR>" "Review branch")
    (normal "<leader>vs" ":Neogit<CR>" "Status")

    # r - review
    (normalVisual "<leader>rc" (luaFunction "require(\"code-review\").add_comment(vim.v.count > 0 and vim.v.count or nil)") "Add comment")
    (normal "<leader>rd" ":CodeReviewDeleteComment<CR>" "Delete comment")
    (normal "<leader>rl" ":CodeReviewList<CR>" "List comments")
    (normal "<leader>ro" ":CodeReviewResolve<CR>" "Resolve thread")
    (normal "<leader>rp" ":CodeReviewPreview<CR>" "Preview review")
    (normal "<leader>rr" ":CodeReviewReply<CR>" "Reply to comment")
    (normal "<leader>rs" ":CodeReviewShowComment<CR>" "Show comment")
    (normal "<leader>rx" ":CodeReviewClear<CR>" "Clear all comments")
    (normal "<leader>ry" ":CodeReviewCopy<CR>" "Copy review to clipboard")

    # l - lsp/formatter
    (normal "<leader>la" ":lua vim.lsp.buf.code_action()<CR>" "Actions")
    (normal "<leader>ld" ":lua vim.diagnostic.open_float({ severity = { min = vim.diagnostic.severity.HINT } })<CR>" "Diagnostics popup")
    (normal "<leader>lf" ":lua require('conform').format({ lsp_fallback = true })<CR>" "Format")
    (normal "<leader>li" ":lua vim.lsp.buf.hover()<CR>" "Information")
    (normal "<leader>lj" ":lua vim.diagnostic.jump({ count = 1 })<CR>" "Next diagnostic")
    (normal "<leader>lk" ":lua vim.diagnostic.jump({ count = -1 })<CR>" "Prev diagnostic")
    (normal "<leader>lr" ":lua vim.lsp.buf.rename()<CR>" "Rename")
    (normal "<leader>lR" ":lua vim.lsp.buf.references()<CR>" "References")
    (normal "<leader>ls" ":lua vim.lsp.buf.definition()<CR>" "Source definition")

    # t - tab
    (normal "<leader>tc" ":tabclose<CR>" "Close tab")
    (normal "<leader>tn" ":tabnew<CR>" "New tab")
    (normal "<leader>to" ":tabonly<CR>" "Close other tabs")
    (normal "<leader>th" ":tabprevious<CR>" "Previous tab")
    (normal "<leader>tl" ":tabnext<CR>" "Next tab")

    # w - window
    (normal "<leader>wh" "<C-w>h" "Go left")
    (normal "<leader>wj" "<C-w>j" "Go down")
    (normal "<leader>wk" "<C-w>k" "Go up")
    (normal "<leader>wl" "<C-w>l" "Go right")
    (normal "<leader>ws" ":split<CR>" "Split horizontal")
    (normal "<leader>wv" ":vsplit<CR>" "Split vertical")
    (normal "<leader>wc" ":close<CR>" "Close window")
    (normal "<leader>wq" ":q<CR>" "Quit window")
    (normal "<leader>wo" ":only<CR>" "Close other windows")
    (normal "<leader>w=" "<C-w>=" "Equalize windows")

    # scrolling
    (normal "<C-d>" "<C-d>zz" "Scroll down and center")
    (normal "<C-u>" "<C-u>zz" "Scroll up and center")

    # other
    (normal "<leader>j" (luaFunction "require('flash').jump()") "Jump to character")
    (normal "<leader>a" ":lua require('harpoon'):list():add()<CR>" "Add harpoon")
    (normal "<C-e>" ":lua require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())<CR>" "Toggle harpoon quick menu")
    (normal "<leader>1" ":lua require('harpoon'):list():select(1)<CR>" "Go to harpoon 1")
    (normal "<leader>2" ":lua require('harpoon'):list():select(2)<CR>" "Go to harpoon 2")
    (normal "<leader>3" ":lua require('harpoon'):list():select(3)<CR>" "Go to harpoon 3")
    (normal "<leader>4" ":lua require('harpoon'):list():select(4)<CR>" "Go to harpoon 4")

    # z - zk (notes)
    (normal "<leader>zn" ":ZkNew { title = vim.fn.input('Title: ') }<CR>" "New note")
    (normal "<leader>zo" ":ZkNotes { sort = { 'modified' } }<CR>" "Open notes")
    (normal "<leader>zt" ":ZkTags<CR>" "Browse tags")
    (normal "<leader>zf" ":ZkNotes { sort = { 'modified' }, match = { vim.fn.input('Search: ') } }<CR>" "Find notes")
    (visual "<leader>zf" ":'<,'>ZkMatch<CR>" "Find notes matching selection")
    (normal "<leader>zb" ":ZkBacklinks<CR>" "Backlinks")
    (normal "<leader>zl" ":ZkLinks<CR>" "Outbound links")
    (normal "<leader>zi" ":ZkInsertLink<CR>" "Insert link")
    (visual "<leader>zi" ":'<,'>ZkInsertLinkAtSelection<CR>" "Insert link at selection")
    (visual "<leader>zc" ":'<,'>ZkNewFromTitleSelection<CR>" "Create note from selection")
  ];
}
