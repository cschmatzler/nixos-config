{
  config,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../shared.nix
  ];

  networking.hostName = "jason";
  networking.computerName = "Jason";

  home-manager.users.${user} = {
    programs.git.userEmail = "christoph@schmatzler.com";
  };
}
