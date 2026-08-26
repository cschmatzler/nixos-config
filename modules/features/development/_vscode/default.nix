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
          alefragnani.bookmarks
          asvetliakov.vscode-neovim
          davidanson.vscode-markdownlint
          eamodio.gitlens
          github.vscode-pull-request-github
          jnoortheen.nix-ide
          mkhl.direnv
          ms-azuretools.vscode-docker
          ms-vscode-remote.remote-ssh
          mvllow.rose-pine
          oxc.oxc-vscode
          pkief.material-icon-theme
          redhat.vscode-yaml
          usernamehw.errorlens
          vspacecode.whichkey
        ];

        userSettings = import ./settings.nix {inherit config pkgs;};
        userTasks = import ./tasks.nix;
      };
    };
  };
}
