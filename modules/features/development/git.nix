_:
with (import ../../_lib/theme.nix).rosePine; {
  den.aspects.git.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      delta
      gh
      serie
      tea
    ];

    programs.git = {
      enable = true;
      ignores = ["*.swp"];
      settings = {
        user.name = (import ../../_lib/local.nix).user.fullName;
        init.defaultBranch = "main";
        core = {
          editor = "nvim";
          autocrlf = "input";
          pager = "delta";
        };
        credential = {
          helper = "!gh auth git-credential";
          "https://github.com".useHttpPath = true;
          "https://gist.github.com".useHttpPath = true;
        };
        alias = {
          st = "status --short --branch";
          sw = "switch";
          co = "checkout";
          br = "branch";
          ci = "commit";
          cm = "commit -m";
          ca = "commit --amend";
          aa = "add --all";
          unstage = "restore --staged";
          last = "log -1 HEAD --stat";
          lg = "log --graph --decorate --oneline --abbrev-commit";
          graph = "log --graph --decorate --oneline --abbrev-commit --all";
          rb = "rebase";
          rbc = "rebase --continue";
          rba = "rebase --abort";
          pf = "push --force-with-lease";
          please = "push --force-with-lease";
          gone = "branch --merged";
        };
        fetch = {
          prune = true;
          pruneTags = true;
        };
        push = {
          autoSetupRemote = true;
          default = "current";
        };
        pull.rebase = true;
        rebase.autoStash = true;
        interactive.diffFilter = "delta --color-only";
        delta = {
          navigate = true;
          line-numbers = true;
          light = false;
          syntax-theme = deltaSyntaxTheme;
          side-by-side = true;
          pager = "less -FRX";
        };
        pager = {
          diff = "delta";
          log = "delta";
          show = "delta";
        };
      };
      lfs.enable = true;
    };

    programs.lazygit = {
      enable = true;
      settings = {
        git.diffRenderers = [
          {
            colorArg = "always";
            command = "delta --paging=never";
          }
        ];
        gui = {
          theme = {
            lightTheme = false;
            activeBorderColor = [hex.iris "bold"];
            inactiveBorderColor = [hex.muted];
            searchingActiveBorderColor = [hex.foam "bold"];
            optionsTextColor = [hex.pine];
            selectedLineBgColor = [hex.overlay];
            inactiveViewSelectedLineBgColor = [hex.surface];
            cherryPickedCommitFgColor = [hex.pine];
            cherryPickedCommitBgColor = [hex.foam];
            markedBaseCommitFgColor = [hex.rose];
            markedBaseCommitBgColor = [hex.gold];
            unstagedChangesColor = [hex.love];
            defaultFgColor = [hex.text];
          };
          nerdFontsVersion = "3";
        };
        os = {
          editPreset = "nvim";
          editInTerminal = true;
        };
      };
    };
  };
}
