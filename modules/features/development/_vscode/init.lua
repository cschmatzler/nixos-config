-- VS Code owns the UI, LSP, completion, Git, and file pickers. This init keeps
-- Neovim's editing model and the text-editing plugins that work well headlessly.
vim.opt.loadplugins = false
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.expandtab = true
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = ""
vim.opt.scrolloff = 8
vim.opt.undofile = true

pcall(function()
  vim.cmd("packadd! mini.nvim")

  local ai = require("mini.ai")
  ai.setup({
    custom_textobjects = {
      B = require("mini.extra").gen_ai_spec.buffer(),
    },
  })
  require("mini.align").setup()
  require("mini.splitjoin").setup()
  require("mini.surround").setup()
end)

pcall(function()
  vim.cmd("packadd! hardtime.nvim")
  require("hardtime").setup()
end)

local flash_available = pcall(function()
  vim.cmd("packadd! flash.nvim")
  require("flash").setup()
end)

local vscode = require("vscode")
local map = vim.keymap.set

local function action(modes, lhs, command, description)
  map(modes, lhs, function()
    vscode.action(command)
  end, { desc = description, silent = true })
end

local function task(modes, lhs, label, description)
  map(modes, lhs, function()
    vscode.action("workbench.action.tasks.runTask", { args = { label } })
  end, { desc = description, silent = true })
end

map({ "n", "x" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })

-- e: explore/edit
action("n", "<leader>ef", "workbench.view.explorer", "Explorer")
action("n", "<leader>er", "workbench.action.replaceInFiles", "Search and replace")

-- f: find
action("n", "<leader>f/", "workbench.action.quickTextSearch", "Search history")
action("n", "<leader>f:", "workbench.action.showCommands", "Commands")
action("n", "<leader>fa", "workbench.view.scm", "Staged changes")
action("n", "<leader>fA", "git.openChange", "Current staged change")
action("n", "<leader>fb", "workbench.action.showAllEditors", "Buffers")
action("n", "<leader>fd", "workbench.actions.view.problems", "Workspace diagnostics")
action("n", "<leader>fD", "workbench.actions.view.problems", "Buffer diagnostics")
action("n", "<leader>ff", "workbench.action.quickOpen", "Find files")
action("n", "<leader>fg", "workbench.action.findInFiles", "Live grep")
action("n", "<leader>fm", "git.openAllChanges", "Modified files")
action("n", "<leader>fM", "git.openChange", "Current file changes")
action("n", "<leader>fr", "editor.action.findReferences", "References")
action("n", "<leader>fs", "workbench.action.showAllSymbols", "Workspace symbols")
action("n", "<leader>fS", "workbench.action.gotoSymbol", "Buffer symbols")
action("n", "<leader>fv", "workbench.action.openRecent", "Recent files")
action("n", "<leader>fV", "workbench.action.openRecent", "Recent files in workspace")

-- v: version control
action("n", "<leader>va", "gitlens.toggleFileBlame", "Toggle blame")
action("n", "<leader>vd", "git.openChange", "Diff current file")
action("n", "<leader>vD", "git.openAllChanges", "Diff all changes")
action("n", "<leader>ve", "git.commit", "Commit")
action("n", "<leader>vf", "git.fetchAll", "Fetch")
action("n", "<leader>vv", "workbench.view.scm", "Source control")
action("n", "<leader>vh", "git.openHEADFile", "Open HEAD version")
action("n", "<leader>vl", "workbench.view.extension.gitlens", "Git log")
action("n", "<leader>vn", "git.checkout", "Branch")
action("n", "<leader>vp", "git.push", "Push")
action("n", "<leader>vq", "workbench.action.closeActiveEditor", "Close diff")
action("n", "<leader>vR", "workbench.view.extension.github-pull-requests", "Review branch")
action("n", "<leader>vs", "workbench.view.scm", "Status")

-- r: review
action({ "n", "x" }, "<leader>rc", "pr.addFileComment", "Add review comment")
action("n", "<leader>rd", "pr.deleteComment", "Delete review comment")
action("n", "<leader>rl", "workbench.view.extension.github-pull-requests", "Pull requests")
action("n", "<leader>ro", "pr.resolveReviewThread", "Resolve review thread")
action("n", "<leader>rp", "pr.openAllDiffs", "Open review diffs")
action("n", "<leader>rr", "pr.addFileComment", "Reply to review comment")
action("n", "<leader>rs", "pr.openDescription", "Show pull request")
action("n", "<leader>rx", "pr.closeRelatedEditors", "Close review editors")
action("n", "<leader>ry", "review.copyPrLink", "Copy pull request link")

-- l: language/LSP
action("n", "<leader>la", "editor.action.quickFix", "Code actions")
action("n", "<leader>ld", "editor.action.marker.next", "Diagnostics")
action("n", "<leader>lf", "editor.action.formatDocument", "Format")
action("n", "<leader>li", "editor.action.showHover", "Information")
action("n", "<leader>lj", "editor.action.marker.next", "Next diagnostic")
action("n", "<leader>lk", "editor.action.marker.prev", "Previous diagnostic")
action("n", "<leader>lr", "editor.action.rename", "Rename")
action("n", "<leader>lR", "editor.action.findReferences", "References")
action("n", "<leader>ls", "editor.action.revealDefinition", "Source definition")

-- t: tab/editor
action("n", "<leader>tc", "workbench.action.closeActiveEditor", "Close tab")
action("n", "<leader>tn", "workbench.action.files.newUntitledFile", "New tab")
action("n", "<leader>to", "workbench.action.closeOtherEditors", "Close other tabs")
action("n", "<leader>th", "workbench.action.previousEditorInGroup", "Previous tab")
action("n", "<leader>tl", "workbench.action.nextEditorInGroup", "Next tab")

-- w: window/editor group
action("n", "<leader>wh", "workbench.action.focusLeftGroup", "Go left")
action("n", "<leader>wj", "workbench.action.focusBelowGroup", "Go down")
action("n", "<leader>wk", "workbench.action.focusAboveGroup", "Go up")
action("n", "<leader>wl", "workbench.action.focusRightGroup", "Go right")
action("n", "<leader>ws", "workbench.action.splitEditorDown", "Split horizontal")
action("n", "<leader>wv", "workbench.action.splitEditorRight", "Split vertical")
action("n", "<leader>wc", "workbench.action.closeEditorsAndGroup", "Close window")
action("n", "<leader>wq", "workbench.action.closeEditorsAndGroup", "Quit window")
action("n", "<leader>wo", "workbench.action.closeEditorsInOtherGroups", "Close other windows")
action("n", "<leader>w=", "workbench.action.evenEditorWidths", "Equalize windows")

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })

map("n", "<leader>j", function()
  if flash_available then
    require("flash").jump()
  else
    vscode.action("workbench.action.gotoLine")
  end
end, { desc = "Jump to character", silent = true })

-- Bookmarks approximate Harpoon's fast file list; editor indexes are its slots.
action("n", "<leader>a", "bookmarks.toggle", "Add bookmark")
action("n", "<C-e>", "bookmarks.listFromAllFiles", "Bookmarks")
action("n", "<leader>1", "workbench.action.openEditorAtIndex1", "Go to editor 1")
action("n", "<leader>2", "workbench.action.openEditorAtIndex2", "Go to editor 2")
action("n", "<leader>3", "workbench.action.openEditorAtIndex3", "Go to editor 3")
action("n", "<leader>4", "workbench.action.openEditorAtIndex4", "Go to editor 4")
action("n", "<leader>?", "whichkey.show", "Show leader bindings")

-- z: zk notes, implemented as user tasks so they work locally and over SSH.
task("n", "<leader>zn", "zk: New note", "New note")
task("n", "<leader>zo", "zk: Open notes", "Open notes")
task("n", "<leader>zt", "zk: Browse tag", "Browse tags")
task("n", "<leader>zf", "zk: Find notes", "Find notes")
task("x", "<leader>zf", "zk: Find selected text", "Find notes matching selection")
task("n", "<leader>zb", "zk: Backlinks", "Backlinks")
task("n", "<leader>zl", "zk: Outbound links", "Outbound links")
task("x", "<leader>zc", "zk: New note from selection", "Create note from selection")
