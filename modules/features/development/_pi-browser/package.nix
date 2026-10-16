{pkgs}: let
  inherit (pkgs) lib;
  config = pkgs.writeText "pi-browser-config.json" "{}";
  program = pkgs.replaceVars ./pi-browser.py {
    python = "${pkgs.python3}/bin/python3";
    agent = lib.getExe pkgs.agent-browser;
    chromium = lib.getExe pkgs.chromium;
    inherit config;
    path = lib.makeBinPath [pkgs.coreutils];
    ca = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
in
  # The wrapper depends on source-reviewed CLI/sandbox/lifecycle semantics.
  assert lib.assertMsg (pkgs.agent-browser.version == "0.38.2") "Review pi-browser policy before updating agent-browser";
    pkgs.runCommand "pi-browser-1" {
      meta = {
        description = "Private, screenshot-first native browser operations for Pi";
        mainProgram = "pi-browser";
        platforms = lib.platforms.linux;
      };
    } ''
      install -Dm755 ${program} "$out/bin/pi-browser"
    ''
