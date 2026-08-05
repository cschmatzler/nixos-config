_: {
  den.aspects.javascript.homeManager = {
    config,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      bun
      nodejs_24
      pnpm
    ];
    home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  };
}
