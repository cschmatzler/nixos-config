{den, ...}: let
  local = import ./_lib/local.nix;
in {
  den.aspects = {
    host-darwin-base.includes = [
      den.aspects.darwin-system
      den.aspects.core
      den.aspects.tailscale
      den.aspects.vscode
    ];

    host-nixos-base.includes = [
      den.aspects.nixos-system
      den.aspects.core
      den.aspects.openssh
      den.aspects.tailscale
    ];

    user-workstation.includes = [
      den.aspects.secrets
      den.aspects.shell
      den.aspects.ssh-client
      den.aspects.ghostty
      den.aspects.cli-tools
      den.aspects.git
      den.aspects.dev-tools
      den.aspects.neovim
      den.aspects.vscode
      den.aspects.pi
      den.aspects.claude-code
      den.aspects.plannotator
      den.aspects.herdr
      den.aspects.entire
      den.aspects.zk
    ];

    user-personal.homeManager.programs.git.settings.user.email = local.user.emails.personal;
    user-work.homeManager.programs.git.settings.user.email = local.user.emails.work;
  };
}
