let
  local = import ../../_lib/local.nix;
  theme = (import ../../_lib/theme.nix).rosePineDawn;
in {
  den.aspects.zed = {
    darwin = {pkgs, ...}: {
      environment.systemPackages = [pkgs.brewCasks.zed];
    };

    homeManager = {
      lib,
      pkgs,
      ...
    }: {
      config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        programs.zed-editor = {
          enable = true;
          package = null;
          mutableUserSettings = false;
          mutableUserKeymaps = false;

          extensions = [
            "nix"
            "rose-pine-theme"
          ];

          userSettings = {
            theme = theme.displayName;
            vim_mode = true;

            buffer_font_family = "TX-02";
            buffer_font_size = 14;
            ui_font_size = 15;

            tab_size = 2;
            hard_tabs = false;
            soft_wrap = "none";
            relative_line_numbers = "enabled";
            vertical_scroll_margin = 8;
            scroll_beyond_last_line = "vertical_scroll_margin";
            format_on_save = "on";
            inlay_hints.enabled = true;

            edit_predictions.provider = "none";
            telemetry = {
              diagnostics = false;
              metrics = false;
            };

            ssh_connections = [
              {
                host = local.tailscaleHost "tahani";
                username = local.user.name;
                nickname = "tahani";
                projects = map (path: {paths = [path];}) [
                  "~/Projects/Phase0/be-wefar-webapi"
                  "~/Projects/Phase0/wefar-monorepo"
                  "~/Projects/Personal/reverie"
                  "~/Projects/Personal/roasted"
                  "~/nixos-config"
                ];
              }
            ];

            project_panel = {
              dock = "left";
              entry_spacing = "standard";
              hide_hidden = false;
            };

            languages = {
              Nix.formatter.external = {
                command = "alejandra";
                arguments = [];
              };
              JavaScript.formatter.external = {
                command = "oxfmt";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
              TypeScript.formatter.external = {
                command = "oxfmt";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
              TSX.formatter.external = {
                command = "oxfmt";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };

          userKeymaps = [
            {
              context = "VimControl && !menu";
              bindings = {
                "space e f" = "project_panel::ToggleFocus";

                "space f b" = "tab_switcher::ToggleAll";
                "space f f" = "file_finder::Toggle";
                "space f g" = "pane::DeploySearch";
                "space f r" = "editor::FindAllReferences";
                "space f s" = "project_symbols::Toggle";
                "space f shift-s" = "outline::Toggle";

                "space l a" = "editor::ToggleCodeActions";
                "space l d" = "editor::GoToDiagnostic";
                "space l f" = "editor::Format";
                "space l i" = "editor::Hover";
                "space l r" = "editor::Rename";
                "space l shift-r" = "editor::FindAllReferences";
                "space l s" = "editor::GoToDefinition";

                "space v s" = "git_panel::ToggleFocus";

                "space w c" = "pane::CloseActiveItem";
                "space w h" = "workspace::ActivatePaneLeft";
                "space w j" = "workspace::ActivatePaneDown";
                "space w k" = "workspace::ActivatePaneUp";
                "space w l" = "workspace::ActivatePaneRight";
                "space w s" = "pane::SplitDown";
                "space w v" = "pane::SplitRight";

                "space j" = "vim::HelixJumpToWord";
              };
            }
            {
              context = "Dock";
              bindings = {
                "ctrl-w h" = "workspace::ActivatePaneLeft";
                "ctrl-w j" = "workspace::ActivatePaneDown";
                "ctrl-w k" = "workspace::ActivatePaneUp";
                "ctrl-w l" = "workspace::ActivatePaneRight";
              };
            }
          ];
        };
      };
    };
  };
}
