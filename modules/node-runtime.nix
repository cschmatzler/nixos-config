_: {
  den.aspects.node-runtime.homeManager = {
    config,
    pkgs,
    ...
  }: {
    home.packages = [pkgs.nodejs_24];
    home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  };
}
