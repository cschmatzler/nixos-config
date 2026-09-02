_: {
  den.aspects.dev-tools.homeManager = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # nix
        alejandra
        deadnix
        nil
        nurl
        statix
        # javascript
        bun
        nodejs_24
        oxfmt
        pnpm
        # containers / databases
        docker
        docker-compose
        lazydocker
        postgresql_17
        sqlite
        # misc
        ast-grep
        fnox
        gnumake
        hk
        hyperfine
        mosh
        tokei
        tree-sitter
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [xcodes]
      ++ lib.optionals stdenv.hostPlatform.isLinux [chromium gcc15];

    home.sessionVariables =
      {
        NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        CHROMIUM_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
      };
  };
}
