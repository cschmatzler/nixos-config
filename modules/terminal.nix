{...}: let
  theme = (import ./_lib/theme.nix).catppuccinMocha;
  palette = theme.hex;
in {
  den.aspects.terminal.homeManager = {
    config,
    pkgs,
    lib,
    ...
  }: let
    ghosttySettings = import ./_terminal/ghostty.nix {inherit pkgs theme;};
    glowFiles = import ./_terminal/glow.nix {inherit config theme;};
    ghosttyConfig =
      lib.generators.toKeyValue {
        mkKeyValue = key: value: "${key} = ${
          if lib.isBool value
          then lib.boolToString value
          else toString value
        }";
      }
      ghosttySettings;
    jsonFormat = pkgs.formats.json {};
    yamlFormat = pkgs.formats.yaml {};
    batThemeSrc = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "bat";
      rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
      hash = "sha256-lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
    };
    yaziThemeSrc = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "yazi";
      rev = "41f24ed142e34109a9a65a5dfe58c1b4eb6d2fd9";
      hash = "sha256-Og33IGS9pTim6LEH33CO102wpGnPomiperFbqfgrJjw=";
    };
  in {
    home.packages = with pkgs;
      [
        dust
        fastfetch
        fd
        geist-font
        glow
        htop
        jq
        killall
        lsof
        ouch
        ov
        sd
        tree
      ]
      ++ lib.optionals stdenv.isLinux [
        ghostty.terminfo
      ];

    home.sessionVariables = {
      FZF_DEFAULT_OPTS = ''
        --bind=alt-k:up,alt-j:down
        --expect=tab,enter
        --layout=reverse
        --delimiter='\t'
        --with-nth=1
        --preview-window='border-rounded' --prompt='  ' --marker=' ' --pointer=' '
        --separator='─' --scrollbar='┃' --layout='reverse'

        --color=bg+:${palette.overlay},bg:${palette.base},spinner:${palette.gold},hl:${palette.rose}
        --color=fg:${palette.subtle},header:${palette.pine},info:${palette.foam},pointer:${palette.iris}
        --color=marker:${palette.love},fg+:${palette.text},prompt:${palette.subtle},hl+:${palette.rose}
        --color=selected-bg:${palette.overlay}
        --color=border:${palette.highlightMed},label:${palette.text}
      '';
    };

    xdg.configFile = {
      "ghostty/config".text = ghosttyConfig;
      "glow/glow.yml" = {
        source = yamlFormat.generate "glow.yml" glowFiles.settings;
      };
      "glow/${theme.slug}.json" = {
        source = jsonFormat.generate "${theme.slug}.json" glowFiles.theme;
      };
      "yazi/Catppuccin-mocha.tmTheme".source = "${batThemeSrc}/themes/${theme.displayName}.tmTheme";
      "yazi/theme.toml".source = "${yaziThemeSrc}/themes/mocha/catppuccin-mocha-maroon.toml";
    };

    programs.bat = {
      enable = true;
      config = {
        theme = theme.displayName;
        pager = "ov";
      };
      themes = {
        "${theme.displayName}" = {
          src = batThemeSrc;
          file = "themes/${theme.displayName}.tmTheme";
        };
      };
    };

    programs.fzf = {
      enable = true;
      historyWidget.fish.command = "";
    };

    programs.ripgrep = {
      enable = true;
      arguments = [
        "--max-columns=150"
        "--max-columns-preview"
        "--hidden"
        "--smart-case"
        "--colors=column:none"
        "--colors=column:fg:4"
        "--colors=column:style:underline"
        "--colors=line:none"
        "--colors=line:fg:4"
        "--colors=match:none"
        "--colors=match:bg:0"
        "--colors=match:fg:6"
        "--colors=path:none"
        "--colors=path:fg:14"
        "--colors=path:style:bold"
      ];
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
      settings = {
        manager = {
          show_hidden = true;
          sort_by = "natural";
          sort_dir_first = true;
        };
      };
    };
  };
}
