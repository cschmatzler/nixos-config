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
      ++ lib.optionals stdenv.isDarwin [
        xcodes
      ]
      ++ lib.optionals stdenv.isLinux [
        chromium
        gcc15
      ];

    home.sessionVariables = lib.optionalAttrs pkgs.stdenv.isLinux {
      CHROMIUM_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
    };
  };
}
