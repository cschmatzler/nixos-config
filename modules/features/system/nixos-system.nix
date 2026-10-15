{inputs, ...}:
with import ../../_lib/local.nix; {
  den.aspects.nixos-system.nixos = {pkgs, ...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    security.sudo.enable = true;
    security.sudo.extraRules = [
      {
        users = [user.name];
        commands = [
          {
            command = "/run/current-system/sw/bin/nix-env";
            options = ["NOPASSWD"];
          }
          {
            command = "/nix/store/*/bin/switch-to-configuration";
            options = ["NOPASSWD"];
          }
          {
            command = "/nix/store/*/bin/activate";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    time.timeZone = "UTC";

    nix.settings.trusted-users = [user.name];

    users.users = {
      ${user.name} = {
        isNormalUser = true;
        home = mkHome "x86_64-linux";
        extraGroups = [
          "wheel"
          "systemd-journal"
        ];
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = user.ssh.authorizedKeys;
      };
    };
  };
}
