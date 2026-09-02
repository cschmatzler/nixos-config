_: let
  theme = import ../../_lib/theme.nix;
  inherit (theme) name hex slug;
in {
  den.aspects.cli-tools.homeManager = {
    config,
    pkgs,
    ...
  }: let
    glowConfig = import ./_cli-tools/glow.nix {inherit config theme;};
  in {
    home.packages = with pkgs; [
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
    ];

    home.sessionVariables.FZF_DEFAULT_OPTS = ''
      --bind=alt-k:up,alt-j:down
      --expect=tab,enter
      --layout=reverse
      --delimiter='\t'
      --with-nth=1
      --preview-window='border-rounded' --prompt='  ' --marker=' ' --pointer=' '
      --separator='─' --scrollbar='┃'

      --color=bg+:${hex.overlay},bg:${hex.base},spinner:${hex.gold},hl:${hex.rose}
      --color=fg:${hex.subtle},header:${hex.pine},info:${hex.foam},pointer:${hex.iris}
      --color=marker:${hex.love},fg+:${hex.text},prompt:${hex.subtle},hl+:${hex.rose}
      --color=selected-bg:${hex.overlay}
      --color=border:${hex.highlightMed},label:${hex.text}
    '';

    xdg.configFile = {
      "glow/glow.yml".source =
        (pkgs.formats.yaml {}).generate "glow.yml"
        glowConfig.settings;
      "glow/${slug}.json".source =
        (pkgs.formats.json {}).generate "${slug}.json"
        glowConfig.theme;
    };

    programs = {
      bat = {
        enable = true;
        config = {
          theme = name;
          pager = "ov";
        };
        themes.${name} = {
          src = pkgs.fetchFromGitHub {
            owner = "rose-pine";
            repo = "tm-theme";
            rev = "6d556734541ccb04172e81fd58de4a35fff72d19";
            hash = "sha256-5+fG21KbB7bdPvszkz9Ftl6fCDGs17fJNTAXFRFWZGo=";
          };
          file = "dist/${slug}.tmTheme";
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
        flavors.${slug} = "${pkgs.fetchFromGitHub {
          owner = "rose-pine";
          repo = "yazi";
          rev = "c89d745573d4fcfe0550fe6646f9f9ab1c0e51db";
          hash = "sha256-9e3dXViWl1rK9BPrGAFfs9ZL/tsG6Njz6ksuU6AIrFY=";
        }}/flavors/${slug}.yazi";
        theme.flavor.light = slug;
        settings.manager = {
          show_hidden = true;
          sort_by = "natural";
          sort_dir_first = true;
        };
      };
    };
  };
}
