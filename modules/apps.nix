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
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    descriptions = {
      apply = "Build and apply configuration";
      build = "Build configuration";
      rollback = "Rollback to previous generation";
      update = "Update flake inputs and regenerate flake.nix";
    };
    runtimePath = pkgs.lib.makeBinPath [
      pkgs.alejandra
      pkgs.git
      pkgs.nix
    ];
    hostCases = pkgs.lib.concatStringsSep "\n" (
      pkgs.lib.mapAttrsToList (host: kind: ''
        ${pkgs.lib.escapeShellArg host}) kind=${pkgs.lib.escapeShellArg kind} ;;
      '')
      hostKinds
    );
    mkPlatformApp = name: {
      type = "app";
      program = "${(pkgs.writeShellScriptBin name ''
        PATH=${runtimePath}:$PATH
        exec ${pkgs.bash}/bin/bash ${inputs.self}/apps/${system}/${name} "$@"
      '')}/bin/${name}";
      meta.description = descriptions.${name};
    };
    mkSharedApp = name: {
      type = "app";
      program = "${(pkgs.writeShellScriptBin name ''
        PATH=${runtimePath}:$PATH
        exec ${pkgs.bash}/bin/bash ${inputs.self}/apps/${name} "$@"
      '')}/bin/${name}";
      meta.description = descriptions.${name};
    };
    buildApp = {
      type = "app";
      program = "${(pkgs.writeShellScriptBin "build" ''
        PATH=${runtimePath}:$PATH
        source ${inputs.self}/apps/common.sh

        hostname="''${1:-}"
        if [[ $# -gt 0 ]]; then
          shift
        fi

        host="$(resolve_host "$hostname")"
        case "$host" in
          ${hostCases}
          *)
            print_error "Unknown host: $host"
            exit 1
            ;;
        esac

        build_config "$kind" "$host" "$@"
      '')}/bin/build";
      meta.description = descriptions.build;
    };
    platformAppNames = ["rollback"];
    sharedAppNames = ["apply" "update"];
  in {
    formatter = pkgs.alejandra;
    apps =
      pkgs.lib.genAttrs platformAppNames mkPlatformApp
      // pkgs.lib.genAttrs sharedAppNames mkSharedApp
      // {build = buildApp;};
  };
}
