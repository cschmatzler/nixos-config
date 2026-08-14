_: {
  den.aspects.dev-cli.homeManager = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        ast-grep
        fnox
        gnumake
        hk
        hyperfine
        tokei
        tree-sitter
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        xcodes
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        chromium
        gcc15
      ];

    home.sessionVariables = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      CHROMIUM_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
    };
  };
}
