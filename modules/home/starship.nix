{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "[$directory$git_commit$git_branch$git_status]($style)$character";
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
        format = "[$hash]($style) ";
      };
      git_branch = {
        format = "[$branch]($style) ";
        symbol = "";
      };
      git_status = {
        format = "| [$all_status$ahead_behind]($style) ";
      };
    };
  };
}
