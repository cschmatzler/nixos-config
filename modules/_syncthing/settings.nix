{local}: let
  deviceIds = {
    tahani = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";
    janet = "MJ3WG4R-REHF6JK-LCTHR2Y-4Q3Q2JE-YHO6CPW-6ZADQIX-KURTNMA-LSIPDQT";
  };
  devices =
    builtins.mapAttrs (host: id: {
      inherit id;
      addresses = ["tcp://${local.tailscaleHost host}:22000"];
    })
    deviceIds;
in
  homeDir: {
    inherit devices;

    folders = {
      Clearly = {
        path = "${homeDir}/Clearly";
        devices = ["tahani" "janet"];
      };
    };

    options = {
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      relaysEnabled = false;
    };
  }
