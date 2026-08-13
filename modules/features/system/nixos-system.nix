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

    nix = {
      settings.trusted-users = [user.name];
      gc.dates = "weekly";
      nixPath = [
        "nixos-config=${mkHome "x86_64-linux"}/.local/share/src/nixos-config"
        "/etc/nixos"
      ];
    };

    users.users = {
      ${user.name} = {
        isNormalUser = true;
        home = mkHome "x86_64-linux";
        extraGroups = [
          "wheel"
          "sudo"
          "network"
          "systemd-journal"
        ];
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = user.ssh.authorizedKeys;
      };
    };
  };
}
