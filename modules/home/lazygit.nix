{
  programs.lazygit = {
    enable = true;
    settings = {
      git = {
        paging = {
          colorArg = "always";
          pager = "DELTA_FEATURES=decorations delta --light --paging=never --line-numbers --hyperlinks --hyperlinks-file-link-format=\"lazygit-edit://{path}:{line}\"";
        };

        commit = {
          signOff = true;
        };
      };

      gui = {
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
          unstagedChangesColor = [
            "#d20f39"
          ];
          defaultFgColor = [
            "#4c4f69"
          ];
          searchingActiveBorderColor = [
            "#df8e1d"
          ];
        };

        authorColors = {
          "*" = "#7287fd";
        };
      };
    };
  };

  home.shellAliases = {
    lg = "lazygit";
  };
}
