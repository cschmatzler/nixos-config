{pkgs}: {
  "nix.enableLanguageServer" = true;
  "nix.serverPath" = "${pkgs.nil}/bin/nil";
  "nix.serverSettings".nil.formatting.command = [
    "${pkgs.alejandra}/bin/alejandra"
  ];

  "oxc.enable.oxlint" = false;
  "oxc.enable.oxfmt" = true;
  "oxc.path.oxfmt" = "${pkgs.oxfmt}/bin/oxfmt";

  # Use host-native Nix binaries, including for Marketplace extensions on SSH.
  "direnv.path.executable" = "${pkgs.direnv}/bin/direnv";
  "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
  "rust-analyzer.check.command" = "clippy";
  "[rust]"."editor.defaultFormatter" = "rust-lang.rust-analyzer";
  "[toml]"."editor.defaultFormatter" = "tamasfe.even-better-toml";
}
