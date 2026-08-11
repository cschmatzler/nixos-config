{den, ...}: {
  den.aspects.herdr-sandbox.homeManager = {
    config,
    lib,
    pkgs,
    ...
  }: let
    local = import ../../_lib/local.nix;
    jsonFormat = pkgs.formats.json {};
    sandboxPackage = import ./_herdr-sandbox/package.nix {inherit lib pkgs;};
    sbxPackage = import ./_herdr-sandbox/sbx-package.nix {inherit lib pkgs;};
    stateDirectory = "${config.xdg.stateHome}/herdr-sandbox";
    listenPort = 18743;
    brokerConfig = jsonFormat.generate "herdr-sandbox.json" {
      herdrSocketPath = "${config.xdg.configHome}/herdr/herdr.sock";
      inherit stateDirectory listenPort;
    };
    sandboxShell = pkgs.writeShellScript "herdr-sandbox-shell" ''
      export DOCKER_SANDBOXES_ROOT_SIZE=20g
      export DOCKER_SANDBOXES_DOCKER_SIZE=20g
      export DOCKER_SANDBOXES_ENABLE_VIRTIOFS_CACHE=1
      export HERDR_SANDBOX_SBX=${sbxPackage}/bin/sbx
      export HERDR_SANDBOX_HERDR="$(command -v herdr)"
      export HERDR_SANDBOX_JQ=${lib.getExe pkgs.jq}
      export HERDR_SANDBOX_SHA256SUM=${pkgs.coreutils}/bin/sha256sum
      export HERDR_SANDBOX_OPENSSL=${lib.getExe pkgs.openssl}
      export HERDR_SANDBOX_TAR=${pkgs.gnutar}/bin/tar
      export HERDR_SANDBOX_GH=${lib.getExe pkgs.gh}
      export HERDR_SANDBOX_GIT=${lib.getExe pkgs.git}
      export HERDR_SANDBOX_NIX=${lib.getExe pkgs.nix}
      export HERDR_SANDBOX_KIT=${sandboxPackage}/share/herdr-sandbox/kit
      export HERDR_SANDBOX_HOST_SHELL=${lib.getExe pkgs.fish}
      export HERDR_SANDBOX_HOST_HOME=${lib.escapeShellArg config.home.homeDirectory}
      export HERDR_SANDBOX_HOST_NAME="$(${lib.getExe pkgs.hostname})"
      export HERDR_SANDBOX_HOST_PROFILE="$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg "${config.home.homeDirectory}/.nix-profile"})"
      export HERDR_SANDBOX_HOME_FILES="$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg "${config.xdg.stateHome}/home-manager/gcroots/current-home/home-files"})"
      export HERDR_SANDBOX_STATE_DIRECTORY=${lib.escapeShellArg stateDirectory}
      export HERDR_SANDBOX_SUPERMEMORY_KEY=${lib.escapeShellArg (local.secretPath "supermemory-api-key")}
      export HERDR_SANDBOX_LISTEN_PORT=${toString listenPort}
      export HERDR_SANDBOX_CPUS=4
      export HERDR_SANDBOX_MEMORY=8g
      exec ${lib.getExe pkgs.fish} ${./_herdr-sandbox/shell.fish}
    '';
  in {
    herdrSandbox.shell = "${sandboxShell}";

    home.packages = [
      sandboxPackage
      sbxPackage
    ];

    systemd.user.services.herdr-sandbox = {
      Unit = {
        Description = "Scoped Herdr broker for sandboxed Pi sessions";
        X-SwitchMethod = "restart";
      };
      Service = {
        ExecStart = "${sandboxPackage}/bin/herdr-sandboxd --config ${brokerConfig}";
        Restart = "on-failure";
        RestartSec = 2;
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
