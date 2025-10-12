{
  programs.lazygit = {
    enable = true;
    settings = {
      git = {
        commit.signOff = true;
        paging = {
          colorArg = "always";
          pager = "DELTA_FEATURES=decorations delta --dark --paging=never --line-numbers --hyperlinks --hyperlinks-file-link-format=\"lazygit-edit://{path}:{line}\"";
        };
      };

      gui = {
        authorColors = {
          "*" = "#b4befe";
        };
        theme = {
          activeBorderColor = [
            "#cba6f7"
            "bold"
          ];
          inactiveBorderColor = [
            "#a6adc8"
          ];
          optionsTextColor = [
            "#89b4fa"
          ];
          selectedLineBgColor = [
            "#313244"
          ];
          cherryPickedCommitBgColor = [
            "#45475a"
          ];
          cherryPickedCommitFgColor = [
            "#cba6f7"
          ];
          defaultFgColor = [
            "#cdd6f4"
          ];
          searchingActiveBorderColor = [
            "#f9e2af"
          ];
          unstagedChangesColor = [
            "#f38ba8"
          ];
        };
      };
    };
  };

  home.shellAliases = {
    lg = "lazygit";
  };
}
