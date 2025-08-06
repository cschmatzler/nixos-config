{lib, ...}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 750;

      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_metrics"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      git_branch = {
        format = " [ $branch]($style) ";
      };

      git_metrics = {
        disabled = false;
        added_style = "bold green";
        format = "[+$added]($added_style)/[-$deleted]($deleted_style) ";
      };
    };
  };
}
