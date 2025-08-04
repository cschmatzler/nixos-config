{
  lib,
  ...
}:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 750;

      format = lib.concatStrings [
        "$directory"
        "$\{custom.jj\}"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      custom.jj = {
        ignore_timeout = true;
        description = "The current jj status";
        when = "jj root";
        symbol = "🥋 ";
        command = lib.concatStrings [
          "jj log --revisions @ --no-graph --ignore-working-copy --color always --limit 1 --template '"
          "separate(\" \","
          "  change_id.shortest(4),"
          "  bookmarks,"
          "  \"|\","
          "  concat("
          "    if(conflict, \"💥\"),"
          "    if(divergent, \"🚧\"),"
          "    if(hidden, \"👻\"),"
          "    if(immutable, \"🔒\"),"
          "  ),"
          "  raw_escape_sequence(\"\\x1b[1;32m\") ++ if(empty, \"(empty)\"),"
          "  raw_escape_sequence(\"\\x1b[1;32m\") ++ coalesce("
          "    truncate_end(29, description.first_line(), \"…\"),"
          "    \"(no description set)\","
          "  ) ++ raw_escape_sequence(\"\\x1b[0m\"),"
          ")'"
        ];
      };

      git_state = {
        disabled = true;
      };
      git_commit = {
        disabled = true;
      };
      git_metrics = {
        disabled = true;
      };
      git_branch = {
        disabled = true;
      };
    };
  };
}
