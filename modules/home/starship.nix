{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "$directory$git_commit$git_branch$git_status$git_state$git_metrics$character";
      character = {
        error_symbol = "[✗ ](bold #e64553)";
        success_symbol = "[❯](bold #40a02b)[❯](bold #df8e1d)[❯](bold #dc8a78)";
      };
      directory = {
        truncation_length = 2;
        truncation_symbol = "…/";
        repo_root_style = "bold cyan";
        repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
      };
      git_commit = {
        commit_hash_length = 4;
        only_detached = false;
        tag_disabled = true;
        format = " [$hash]($style)";
        style = "bold #89b4fa";
      };
      git_branch = {
        format = " [$symbol$branch(:$remote_branch)]($style)";
        symbol = " ";
        style = "bold #a6e3a1";
        truncation_length = 28;
      };
      git_status = {
        format = " [$ahead_behind$staged$modified$renamed$deleted$typechanged$untracked$stashed$conflicted]($style)";
        style = "bold #f9e2af";
        conflicted = "✖$count";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕$ahead_count/$behind_count";
        staged = "+$count";
        modified = "~$count";
        renamed = "»$count";
        deleted = "×$count";
        untracked = "?$count";
        stashed = "⚑$count";
        typechanged = "≋$count";
      };
      git_state = {
        format = " [$state($progress_current/$progress_total)]($style)";
        style = "bold #f38ba8";
      };
      git_metrics = {
        disabled = false;
        format = " [+$added/-$deleted]($style)";
        style = "bold #94e2d5";
      };
    };
  };
}
