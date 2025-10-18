{
  programs.lazygit = {
    enable = true;
    settings = {
      git = {
        commit.signOff = true;
        paging = {
          colorArg = "always";
          pager = "DELTA_FEATURES=decorations delta --light --paging=never --line-numbers --hyperlinks --hyperlinks-file-link-format=\"lazygit-edit://{path}:{line}\"";
        };
      };

      gui = {
        authorColors = {
          "*" = "#7287fd";
        };
        theme = {
          activeBorderColor = [
            "#8839ef"
            "bold"
          ];
          inactiveBorderColor = [
            "#6c6f85"
          ];
          optionsTextColor = [
            "#1e66f5"
          ];
          selectedLineBgColor = [
            "#ccd0da"
          ];
          cherryPickedCommitBgColor = [
            "#bcc0cc"
          ];
          cherryPickedCommitFgColor = [
            "#8839ef"
          ];
          defaultFgColor = [
            "#4c4f69"
          ];
          searchingActiveBorderColor = [
            "#df8e1d"
          ];
          unstagedChangesColor = [
            "#d20f39"
          ];
        };
      };
    };
  };

  home.shellAliases = {
    lg = "lazygit";
  };
}
