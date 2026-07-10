{lib, ...}: let
  local = import ./_lib/local.nix;
  secretLib = import ./_lib/secrets.nix {};
  user = local.user.name;
  mkSettings = import ./_syncthing/settings.nix {inherit local;};
  mkDarwinReconcileScript = import ./_syncthing/darwin-rest-reconciliation.nix {
    inherit lib;
  };

  mkSecrets = {
    host,
    homeDir,
    linkToConfig ? false,
  }: {
    "${host}-syncthing-cert" = secretLib.mkUserBinarySecret ({
        name = "${host}-syncthing-cert";
        sopsFile = ../secrets/${host}-syncthing-cert;
      }
      // lib.optionalAttrs linkToConfig {
        path = "${homeDir}/.config/syncthing/cert.pem";
      });
    "${host}-syncthing-key" = secretLib.mkUserBinarySecret ({
        name = "${host}-syncthing-key";
        sopsFile = ../secrets/${host}-syncthing-key;
      }
      // lib.optionalAttrs linkToConfig {
        path = "${homeDir}/.config/syncthing/key.pem";
      });
  };
in {
  den.aspects.syncthing.nixos = {config, ...}: let
    host = config.networking.hostName;
    homeDir = local.mkHome "x86_64-linux";
  in {
    sops.secrets = mkSecrets {
      inherit homeDir host;
    };

    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      dataDir = "${homeDir}/.local/share/syncthing";
      configDir = "${homeDir}/.config/syncthing";
      cert = config.sops.secrets."${host}-syncthing-cert".path;
      key = config.sops.secrets."${host}-syncthing-key".path;
      inherit user;
      group = "users";
      guiAddress = "127.0.0.1:8384";
      overrideFolders = true;
      overrideDevices = true;
      settings = mkSettings homeDir;
    };
  };

  den.aspects.syncthing.darwin = {
    config,
    pkgs,
    ...
  }: let
    host = config.networking.hostName;
    homeDir = local.mkHome "aarch64-darwin";
    configDir = "${homeDir}/.config/syncthing";
    guiAddress = "127.0.0.1:8384";
    settings = mkSettings homeDir;
    updateConfig = mkDarwinReconcileScript {
      inherit pkgs configDir guiAddress settings;
    };
  in {
    sops.secrets = mkSecrets {
      inherit homeDir host;
      linkToConfig = true;
    };

    environment.systemPackages = [pkgs.syncthing];

    launchd.user.agents.syncthing.serviceConfig = {
      ProgramArguments = [
        "${pkgs.syncthing}/bin/syncthing"
        "--no-browser"
        "--gui-address=${guiAddress}"
        "--config=${configDir}"
        "--data=${configDir}"
      ];
      EnvironmentVariables = {
        STNORESTART = "yes";
        STNOUPGRADE = "yes";
      };
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
      StandardOutPath = "${configDir}/syncthing.log";
      StandardErrorPath = "${configDir}/syncthing.log";
    };

    launchd.user.agents.syncthing-init.serviceConfig = {
      ProgramArguments = ["${updateConfig}"];
      RunAtLoad = true;
      KeepAlive = false;
      ProcessType = "Background";
      StandardOutPath = "${configDir}/syncthing-init.log";
      StandardErrorPath = "${configDir}/syncthing-init.log";
    };
  };
}
