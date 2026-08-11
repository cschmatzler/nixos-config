{den, ...}: {
  den.aspects.herdr-sandbox.homeManager = {
    config,
    lib,
    pkgs,
    ...
  }: let
    local = import ../../_lib/local.nix;
    jsonFormat = pkgs.formats.json {};
    package = import ./_herdr-sandbox/package.nix {inherit lib pkgs;};
    sbxPackage = import ./_herdr-sandbox/sbx-package.nix {inherit lib pkgs;};
    controllerConfig = jsonFormat.generate "herdr-sandbox.json" {
      herdrSocketPath = "${config.xdg.configHome}/herdr/herdr.sock";
      stateDirectory = "${config.xdg.stateHome}/herdr-sandbox";
      listenPort = 18743;
      sbxPath = "${sbxPackage}/bin/sbx";
      dockerPath = lib.getExe pkgs.docker-client;
      dockerSocketPath = "${config.xdg.stateHome}/sandboxes/sandboxes/sandboxd/docker.sock";
      kitPath = "${package}/share/herdr-sandbox/kit";
      hostShell = "${pkgs.fish}/bin/fish";
      hostHome = config.home.homeDirectory;
      ghPath = lib.getExe pkgs.gh;
      supermemoryApiKeyPath = local.secretPath "supermemory-api-key";
      guestCpus = 4;
      guestMemory = "8g";
      idleMinutes = 10;
    };
    shell = pkgs.writeShellScript "herdr-sandbox-shell" ''
      export DOCKER_SANDBOXES_ROOT_SIZE=20g
      export DOCKER_SANDBOXES_DOCKER_SIZE=20g
      export DOCKER_SANDBOXES_ENABLE_VIRTIOFS_CACHE=1
      exec ${package}/bin/herdr-sandbox-shell --config ${controllerConfig} "$@"
    '';
  in {
    herdrSandbox.shell = "${shell}";

    home.packages = [
      package
      sbxPackage
    ];

    systemd.user.services.herdr-sandbox = {
      Unit = {
        Description = "Herdr bridge and lifecycle reconciler for Docker-sandboxed workspaces";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
        X-SwitchMethod = "restart";
      };
      Service = {
        ExecStart = "${package}/bin/herdr-sandboxd --config ${controllerConfig}";
        Restart = "on-failure";
        RestartSec = 2;
        TimeoutStopSec = 10;
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
