{
  config,
  pkgs,
  lib,
  ...
}:

let
  name = "Christoph Schmatzler";
  user = "cschmatzler";
  email = "christoph@schmatzler.com";
in
{
  ssh = {
    enable = true;
    includes = [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${user}/.ssh/config_external")
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.ssh/config_external")
    ];
    matchBlocks = {
      "github.com" = {
        identitiesOnly = true;
        identityFile = [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${user}/.ssh/id_github")
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.ssh/id_github")
        ];
      };
    };
  };

  git = {
    enable = true;
    ignores = [ "*.swp" ];
    userName = name;
    userEmail = email;
    lfs = {
      enable = true;
    };
    extraConfig = {
      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      # commit.gpgsign = true;
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  fish = {
    enable = true;
  };

  zsh = {
    enable = true;
  };

  starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 750;

      format = lib.concatStrings [
        "$directory"
        "$\{custom.jj\}"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      custom.jj = {
        ignore_timeout = true;
        description = "The current jj status";
        detect_folders = [ ".jj" ];
        symbol = "🥋 ";
        command = lib.concatStrings [
          "jj log --revisions @ --no-graph --ignore-working-copy --color always --limit 1 --template '"
          "separate(\" \","
          "  change_id.shortest(4),"
          "  bookmarks,"
          "  \"|\","
          "  concat("
          "    if(conflict, \"💥\"),"
          "    if(divergent, \"🚧\"),"
          "    if(hidden, \"👻\"),"
          "    if(immutable, \"🔒\"),"
          "  ),"
          "  raw_escape_sequence(\"\\x1b[1;32m\") ++ if(empty, \"(empty)\"),"
          "  raw_escape_sequence(\"\\x1b[1;32m\") ++ coalesce("
          "    truncate_end(29, description.first_line(), \"…\"),"
          "    \"(no description set)\","
          "  ) ++ raw_escape_sequence(\"\\x1b[0m\"),"
          ")"
        ];
      };

      git_state = {
        disabled = true;
      };
      git_commit = {
        disabled = true;
      };
      git_metrics = {
        disabled = true;
      };
      git_branch = {
        disabled = true;
      };
    };
  };

  zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  atuin = {
    enable = true;
    enableFishIntegration = true;
    daemon = {
      enable = true;
    };
  };

  ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      command = "${pkgs.fish}/bin/fish";
      theme = "catppuccin-latte";
      window-padding-x = 8;
      window-padding-y = 2;
      window-padding-balance = true;
      font-family = "Iosevka";
      font-size = 15.5;
      font-feature = [
        "-calt"
        "-dlig"
      ];
      cursor-style = "block";
      mouse-hide-while-typing = true;
      mouse-scroll-multiplier = 1.25;
      shell-integration = "detect";
      shell-integration-features = "no-cursor";

      keybind = [
        "global:ctrl+shift+space=toggle_quick_terminal"
        "shift+enter=text:\\n"
        "ctrl+one=goto_tab:1"
        "ctrl+two=goto_tab:2"
        "ctrl+three=goto_tab:3"
        "ctrl+four=goto_tab:4"
        "ctrl+five=goto_tab:5"
        "ctrl+six=goto_tab:6"
        "ctrl+seven=goto_tab:7"
        "ctrl+eight=goto_tab:8"
        "ctrl+nine=goto_tab:9"
        "ctrl+left=previous_tab"
        "ctrl+right=next_tab"
        "ctrl+h=previous_tab"
        "ctrl+l=next_tab"
        "ctrl+shift+left=goto_split:left"
        "ctrl+shift+right=goto_split:right"
        "ctrl+shift+h=goto_split:left"
        "ctrl+shift+j=goto_split:down"
        "ctrl+shift+k=goto_split:up"
        "ctrl+shift+l=goto_split:right"
        "ctrl+shift+enter=new_split:right"
        "ctrl+t=new_tab"
        "ctrl+w=close_tab"
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
