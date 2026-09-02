_: let
  local = import ../../_lib/local.nix;

  settings = homeDir: {
    devices =
      builtins.mapAttrs (host: id: {
        inherit id;
        addresses = ["tcp://${local.tailscaleHost host}:22000"];
      }) {
        tahani = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";
        janet = "MJ3WG4R-REHF6JK-LCTHR2Y-4Q3Q2JE-YHO6CPW-6ZADQIX-KURTNMA-LSIPDQT";
      };
    folders.Clearly = {
      path = "${homeDir}/Clearly";
      devices = ["tahani" "janet"];
    };
    options = {
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
    };
  };

  secrets = host: {
    "${host}-syncthing-cert" = {
      format = "binary";
      owner = local.user.name;
      sopsFile = ../../../secrets/${host}-syncthing-cert;
    };
    "${host}-syncthing-key" = {
      format = "binary";
      owner = local.user.name;
      sopsFile = ../../../secrets/${host}-syncthing-key;
    };
  };
in {
  den.aspects.syncthing = {
    # NixOS: system service running as the user.
    nixos = {config, ...}: let
      host = config.networking.hostName;
      homeDir = local.mkHome "x86_64-linux";
    in {
      sops.secrets = secrets host;
      services.syncthing = {
        enable = true;
        openDefaultPorts = true;
        user = local.user.name;
        group = "users";
        dataDir = "${homeDir}/.local/share/syncthing";
        configDir = "${homeDir}/.config/syncthing";
        cert = config.sops.secrets."${host}-syncthing-cert".path;
        key = config.sops.secrets."${host}-syncthing-key".path;
        guiAddress = "127.0.0.1:8384";
        overrideDevices = true;
        overrideFolders = true;
        settings = settings homeDir;
      };
    };

    # Darwin: secrets at the OS level, the launchd agent via home-manager.
    darwin = {config, ...}: {
      sops.secrets = secrets config.networking.hostName;
    };
    homeManager = {
      config,
      osConfig,
      ...
    }: let
      host = osConfig.networking.hostName;
    in {
      services.syncthing = {
        enable = true;
        cert = osConfig.sops.secrets."${host}-syncthing-cert".path;
        key = osConfig.sops.secrets."${host}-syncthing-key".path;
        settings = settings config.home.homeDirectory;
      };
    };
  };
}
