_: let
  theme = (import ./_lib/theme.nix).rosePineDawn;
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
    tmThemeSrc = pkgs.fetchFromGitHub {
      owner = "rose-pine";
      repo = "tm-theme";
      rev = "6d556734541ccb04172e81fd58de4a35fff72d19";
      hash = "sha256-5+fG21KbB7bdPvszkz9Ftl6fCDGs17fJNTAXFRFWZGo=";
    };
    yaziThemeSrc = pkgs.fetchFromGitHub {
      owner = "rose-pine";
      repo = "yazi";
      rev = "c89d745573d4fcfe0550fe6646f9f9ab1c0e51db";
      hash = "sha256-9e3dXViWl1rK9BPrGAFfs9ZL/tsG6Njz6ksuU6AIrFY=";
    };
  in {
    fonts.fontconfig = {
      enable = true;
      defaultFonts.monospace = ["MonoLisa"];
    };

    home.packages = with pkgs;
      [
        dust
        fastfetch
        fd
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
        --separator='─' --scrollbar='┃'

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
      "yazi/flavors/${theme.slug}.yazi".source = "${yaziThemeSrc}/flavors/${theme.slug}.yazi";
      "yazi/theme.toml".text = ''
        [flavor]
        light = "${theme.slug}"
      '';
    };

    programs = {
      bat = {
        enable = true;
        config = {
          theme = theme.displayName;
          pager = "ov";
        };
        themes = {
          "${theme.displayName}" = {
            src = tmThemeSrc;
            file = "dist/${theme.slug}.tmTheme";
          };
        };
      };

      fzf = {
        enable = true;
        historyWidget.fish.command = "";
      };

      ripgrep = {
        enable = true;
        arguments = [
          "--max-columns=150"
          "--max-columns-preview"
          "--hidden"
          "--smart-case"
          "--colors=column:none"
          "--colors=column:fg:0x28,0x69,0x83"
          "--colors=column:style:underline"
          "--colors=line:none"
          "--colors=line:fg:0x28,0x69,0x83"
          "--colors=match:none"
          "--colors=match:bg:0xf2,0xe9,0xe1"
          "--colors=match:fg:0x56,0x94,0x9f"
          "--colors=path:none"
          "--colors=path:fg:0x56,0x94,0x9f"
          "--colors=path:style:bold"
        ];
      };

      zoxide = {
        enable = true;
        enableFishIntegration = true;
      };

      yazi = {
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
  };
}
