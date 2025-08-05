{ nixvim, ... }:

{
  imports = [
    nixvim.homeManagerModules.nixvim
    ./options.nix
    ./plugins
  ];

  home.shellAliases.v = "nvim";

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    nixpkgs.useGlobalPackages = true;

    viAlias = true;
    vimAlias = true;

    luaLoader.enable = true;
  };
}
