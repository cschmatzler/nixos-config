let
  task = label: script: args: {
    inherit label;
    type = "shell";
    command = "bash";
    args =
      [
        "-lc"
        script
        label
      ]
      ++ args;
    problemMatcher = [];
    presentation = {
      reveal = "always";
      panel = "shared";
      focus = true;
      clear = true;
    };
  };
in {
  version = "2.0.0";

  inputs = [
    {
      id = "zkTitle";
      type = "promptString";
      description = "Note title";
    }
    {
      id = "zkSearch";
      type = "promptString";
      description = "Search notes";
    }
    {
      id = "zkTag";
      type = "promptString";
      description = "Note tag";
    }
  ];

  tasks = [
    (task "zk: New note" ''
      note="$(zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" new --title "$1" --print-path)"
      code --reuse-window "$note"
    '' ["\${input:zkTitle}"])
    (task "zk: New note from selection" ''
      note="$(zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" new --title "$1" --print-path)"
      code --reuse-window "$note"
    '' ["\${selectedText}"])
    (task "zk: Open notes" ''
      EDITOR='code --reuse-window --wait' zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" edit --interactive --sort modified
    '' [])
    (task "zk: Find notes" ''
      EDITOR='code --reuse-window --wait' zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" edit --interactive --sort modified --match "$1"
    '' ["\${input:zkSearch}"])
    (task "zk: Find selected text" ''
      EDITOR='code --reuse-window --wait' zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" edit --interactive --sort modified --match "$1"
    '' ["\${selectedText}"])
    (task "zk: Browse tag" ''
      EDITOR='code --reuse-window --wait' zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" edit --interactive --sort modified --tag "$1"
    '' ["\${input:zkTag}"])
    (task "zk: Backlinks" ''
      EDITOR='code --reuse-window --wait' zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" edit --interactive --sort modified --link-to "$1"
    '' ["\${file}"])
    (task "zk: Outbound links" ''
      EDITOR='code --reuse-window --wait' zk --notebook-dir "$HOME/Projects/Personal/Zettelkasten" edit --interactive --sort modified --linked-by "$1"
    '' ["\${file}"])
  ];
}
