{inputs, ...}: let
  local = import ./_lib/local.nix;
  userHome = local.mkHome "x86_64-linux";
in {
  den.aspects.nixos-system.nixos = {pkgs, ...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    security.sudo.enable = true;
    security.sudo.extraRules = [
      {
        users = [local.user.name];
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
      settings.trusted-users = [local.user.name];
      gc.dates = "weekly";
      nixPath = [
        "nixos-config=${userHome}/.local/share/src/nixos-config"
        "/etc/nixos"
      ];
    };

    users.users = {
      ${local.user.name} = {
        isNormalUser = true;
        home = userHome;
        extraGroups = [
          "wheel"
          "sudo"
          "network"
          "systemd-journal"
        ];
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = local.user.ssh.authorizedKeys;
      };
    };
  };
}
