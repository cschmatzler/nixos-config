{
  config,
  inputs,
  lib,
  ...
}: let
  nixosHosts = builtins.attrNames config.flake.nixosConfigurations;
  darwinHosts = builtins.attrNames config.flake.darwinConfigurations;
  duplicateHosts = lib.intersectLists nixosHosts darwinHosts;
  hostKinds = assert lib.assertMsg (duplicateHosts == [])
  "Host names must be unique across NixOS and Darwin configurations: ${lib.concatStringsSep ", " duplicateHosts}";
    builtins.mapAttrs (_: _: "nixos") config.flake.nixosConfigurations
    // builtins.mapAttrs (_: _: "darwin") config.flake.darwinConfigurations;
in {
  perSystem = {pkgs, ...}: let
    descriptions = {
      apply = "Build and apply the current Host configuration";
      build = "Build a Host configuration";
      rollback = "Roll back the current Host to a generation";
      update = "Update flake inputs and regenerate flake.nix";
    };
    runtimePath = pkgs.lib.makeBinPath [
      pkgs.alejandra
      pkgs.coreutils
      pkgs.git
      pkgs.nix
    ];
    hostCases = pkgs.lib.concatStringsSep "\n" (
      pkgs.lib.mapAttrsToList (host: kind: ''
        ${pkgs.lib.escapeShellArg host}) printf '%s\n' ${pkgs.lib.escapeShellArg kind} ;;
      '')
      hostKinds
    );
    hostManifest = pkgs.writeText "lifecycle-hosts.sh" ''
      host_kind() {
        case "$1" in
          ${hostCases}
          *) return 1 ;;
        esac
      }
    '';
    mkLifecycleApp = name: {
      type = "app";
      program = "${(pkgs.writeShellScriptBin name ''
        PATH=${runtimePath}:$PATH
        export HOST_MANIFEST=${pkgs.lib.escapeShellArg hostManifest}
        exec ${pkgs.bash}/bin/bash ${inputs.self}/apps/${name} "$@"
      '')}/bin/${name}";
      meta.description = descriptions.${name};
    };
  in {
    formatter = pkgs.alejandra;
    apps = pkgs.lib.genAttrs (builtins.attrNames descriptions) mkLifecycleApp;
  };
}
