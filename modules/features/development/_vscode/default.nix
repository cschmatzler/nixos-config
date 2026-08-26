{
  config,
  lib,
  pkgs,
  ...
}: let
  local = import ../../../_lib/local.nix;
in {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    xdg.configFile."vscode-neovim/init.lua".source = ./init.lua;

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

        userSettings = import ./settings.nix {inherit config pkgs;};
        userTasks = import ./tasks.nix;
      };
    };
  };
}
