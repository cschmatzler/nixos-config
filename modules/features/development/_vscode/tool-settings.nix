{pkgs}: {
  "nix.enableLanguageServer" = true;
  "nix.serverPath" = "${pkgs.nil}/bin/nil";
  "nix.serverSettings".nil.formatting.command = [
    "${pkgs.alejandra}/bin/alejandra"
  ];

  "oxc.enable.oxlint" = false;
  "oxc.enable.oxfmt" = true;
  "oxc.path.oxfmt" = "${pkgs.oxfmt}/bin/oxfmt";
}
