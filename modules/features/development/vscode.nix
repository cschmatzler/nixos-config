{inputs, ...}: let
  local = import ../../_lib/local.nix;
in {
  flake-file.inputs.nixvim = {
    url = "github:nix-community/nixvim";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects = {
    vscode = {
      darwin = {pkgs, ...}: {
        environment.systemPackages = [pkgs.vscode];
        # Keep Vim motions repeatable when a key is held down.
        system.defaults.CustomUserPreferences."com.microsoft.VSCode".ApplePressAndHoldEnabled = false;
      };

      homeManager = {
        config,
        lib,
        pkgs,
        ...
      }: {
        imports = [inputs.nixvim.homeModules.nixvim];

        config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          xdg.configFile."vscode-neovim/init.lua".source = ./_vscode/init.lua;

          # vscode-neovim needs a private Neovim runtime. Keeping Nixvim
          # disabled prevents that runtime from being installed in PATH.
          programs.nixvim = {
            enable = false;
            extraPlugins = with pkgs.vimPlugins; [
              flash-nvim
              hardtime-nvim
              mini-nvim
            ];
            version.enableNixpkgsReleaseCheck = false;
          };

          programs.ssh.settings.tahani = {
            HostName = local.tailscaleHost "tahani";
            User = local.user.name;
          };

          programs.vscode = {
            enable = true;
            package = null;
            mutableExtensionsDir = false;
            profiles.default = {
              enableUpdateCheck = false;
              enableExtensionUpdateCheck = false;
              extensions = with pkgs.vscode-extensions; [
                asvetliakov.vscode-neovim
                jnoortheen.nix-ide
                ms-vscode-remote.remote-ssh
                mvllow.rose-pine
                oxc.oxc-vscode
              ];
              userSettings = import ./_vscode/settings.nix {inherit config pkgs;};
              userTasks = import ./_vscode/tasks.nix;
            };
          };
        };
      };
    };

    vscode-remote.nixos = {pkgs, ...}: {
      # The VS Code server ships dynamically linked binaries. nix-ld provides
      # their expected loader on NixOS.
      programs.nix-ld.enable = true;
      # VS Code Remote SSH uses these while installing and updating its server.
      environment.systemPackages = with pkgs; [bash curl gnutar gzip];
    };

    vscode-remote.homeManager = {pkgs, ...}: {
      # Remote extensions read machine settings from the VS Code server, not
      # from the desktop client's settings file.
      home.file.".vscode-server/data/Machine/settings.json".source = (pkgs.formats.json {}).generate "vscode-remote-settings" (
        (import ./_vscode/tool-settings.nix {inherit pkgs;})
        // {
          "terminal.integrated.profiles.linux".zsh.path = "${pkgs.zsh}/bin/zsh";
          "terminal.integrated.defaultProfile.linux" = "zsh";
        }
      );
    };
  };
}
