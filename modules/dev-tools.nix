{
  den,
  inputs,
  ...
}: let
  local = import ./_lib/local.nix;
  theme = (import ./_lib/theme.nix).catppuccinLatte;
  palette = theme.hex;
in {
  flake-file.inputs.hunk.url = "github:modem-dev/hunk";

  den.aspects.dev-tools = {
    includes = [den.aspects.node-runtime];
    homeManager = {
      pkgs,
      lib,
      ...
    }: let
      userName = local.user.fullName;
    in {
      home.packages = with pkgs;
        [
          alejandra
          ast-grep
          bun
          delta
          deadnix
          docker
          docker-compose
          lazydocker
          gh
          gnumake
          hyperfine
          inputs.hunk.packages.${stdenv.hostPlatform.system}.hunk
          nil
          nurl
          pnpm
          postgresql_17
          serie
          sqlite
          statix
          tea
          tokei
          tree-sitter
        ]
        ++ lib.optionals stdenv.isDarwin [
          xcodes
        ]
        ++ lib.optionals stdenv.isLinux [
          gcc15
        ];

      # Git configuration
      programs.git = {
        enable = true;
        ignores = ["*.swp"];
        settings = {
          user.name = userName;
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
            syntax-theme = theme.deltaSyntaxTheme;
            side-by-side = true;
            pager = "less -FRX";
          };
          pager = {
            diff = "delta";
            log = "delta";
            show = "delta";
          };
        };
        lfs = {
          enable = true;
        };
      };

      programs.lazygit = {
        enable = true;
        settings = {
          git = {
            pagers = [
              {
                colorArg = "always";
                pager = "delta --paging=never";
              }
            ];
          };
          gui = {
            theme = {
              lightTheme = true;
              activeBorderColor = [palette.iris "bold"];
              inactiveBorderColor = [palette.muted];
              searchingActiveBorderColor = [palette.foam "bold"];
              optionsTextColor = [palette.pine];
              selectedLineBgColor = [palette.overlay];
              inactiveViewSelectedLineBgColor = [palette.surface];
              cherryPickedCommitFgColor = [palette.pine];
              cherryPickedCommitBgColor = [palette.foam];
              markedBaseCommitFgColor = [palette.rose];
              markedBaseCommitBgColor = [palette.gold];
              unstagedChangesColor = [palette.love];
              defaultFgColor = [palette.text];
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
  };
}
