_: {
  den.aspects.instagram-mcp.nixos = {pkgs, ...}: let
    package = pkgs.callPackage ./_instagram-mcp/package.nix {};
    python = pkgs.python3.withPackages (_: [package]);
  in {
    systemd.services = {
      instagram-mcp = {
        description = "Instagram MCP server";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"];
        environment = {
          HOME = "/var/lib/instagram-mcp";
          IMAGEIO_FFMPEG_EXE = "${pkgs.ffmpeg}/bin/ffmpeg";
        };
        path = [pkgs.ffmpeg];
        serviceConfig = {
          ExecStart = "${python}/bin/python ${./_instagram-mcp/serve.py}";
          DynamicUser = true;
          StateDirectory = "instagram-mcp";
          StateDirectoryMode = "0700";
          WorkingDirectory = "/var/lib/instagram-mcp";
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = "5s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        };
      };
      instagram-mcp-tailscale = import ../../_lib/tailscale-serve.nix {
        inherit pkgs;
        identity = "svc:instagram";
        port = 8789;
        after = ["instagram-mcp.service"];
      };
    };
  };
}
