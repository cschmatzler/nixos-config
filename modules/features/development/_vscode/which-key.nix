let
  command = key: name: command: {
    inherit key name command;
    type = "command";
  };
  group = key: name: bindings: {
    inherit key name bindings;
    type = "bindings";
  };
in [
  (group "e" "+explore" [
    (command "f" "Files" "workbench.view.explorer")
    (command "r" "Search and replace" "workbench.action.replaceInFiles")
  ])
  (group "f" "+find" [
    (command ":" "Commands" "workbench.action.showCommands")
    (command "b" "Buffers" "workbench.action.showAllEditors")
    (command "d" "Diagnostics" "workbench.actions.view.problems")
    (command "f" "Files" "workbench.action.quickOpen")
    (command "g" "Live grep" "workbench.action.findInFiles")
    (command "m" "Modified files" "git.openAllChanges")
    (command "r" "References" "editor.action.findReferences")
    (command "s" "Workspace symbols" "workbench.action.showAllSymbols")
    (command "S" "Buffer symbols" "workbench.action.gotoSymbol")
    (command "v" "Recent files" "workbench.action.openRecent")
  ])
  (group "l" "+language" [
    (command "a" "Actions" "editor.action.quickFix")
    (command "d" "Diagnostics" "editor.action.marker.next")
    (command "f" "Format" "editor.action.formatDocument")
    (command "i" "Information" "editor.action.showHover")
    (command "j" "Next diagnostic" "editor.action.marker.next")
    (command "k" "Previous diagnostic" "editor.action.marker.prev")
    (command "r" "Rename" "editor.action.rename")
    (command "R" "References" "editor.action.findReferences")
    (command "s" "Source definition" "editor.action.revealDefinition")
  ])
  (group "r" "+review" [
    (command "c" "Add comment" "pr.addFileComment")
    (command "l" "Pull requests" "workbench.view.extension.github-pull-requests")
    (command "o" "Resolve thread" "pr.resolveReviewThread")
    (command "p" "Open all diffs" "pr.openAllDiffs")
    (command "s" "Description" "pr.openDescription")
    (command "x" "Close review editors" "pr.closeRelatedEditors")
    (command "y" "Copy PR link" "review.copyPrLink")
  ])
  (group "t" "+tab" [
    (command "c" "Close" "workbench.action.closeActiveEditor")
    (command "h" "Previous" "workbench.action.previousEditorInGroup")
    (command "l" "Next" "workbench.action.nextEditorInGroup")
    (command "n" "New" "workbench.action.files.newUntitledFile")
    (command "o" "Close others" "workbench.action.closeOtherEditors")
  ])
  (group "v" "+version control" [
    (command "a" "Toggle blame" "gitlens.toggleFileBlame")
    (command "d" "Current diff" "git.openChange")
    (command "D" "All diffs" "git.openAllChanges")
    (command "e" "Commit" "git.commit")
    (command "f" "Fetch" "git.fetchAll")
    (command "l" "Log" "workbench.view.extension.gitlens")
    (command "n" "Branch" "git.checkout")
    (command "p" "Push" "git.push")
    (command "s" "Status" "workbench.view.scm")
  ])
  (group "w" "+window" [
    (command "h" "Go left" "workbench.action.focusLeftGroup")
    (command "j" "Go down" "workbench.action.focusBelowGroup")
    (command "k" "Go up" "workbench.action.focusAboveGroup")
    (command "l" "Go right" "workbench.action.focusRightGroup")
    (command "s" "Split horizontal" "workbench.action.splitEditorDown")
    (command "v" "Split vertical" "workbench.action.splitEditorRight")
    (command "c" "Close group" "workbench.action.closeEditorsAndGroup")
    (command "o" "Close other groups" "workbench.action.closeEditorsInOtherGroups")
    (command "=" "Equalize groups" "workbench.action.evenEditorWidths")
  ])
]
