{
  pkgs,
  user,
  hostMeta,
  ...
}: {
  imports = [
    ../shared.nix
  ];

  networking.hostName = "chidi";
  networking.computerName = "Chidi";

  home-manager.users.${user} = {
    programs.git.userEmail = hostMeta.email;
  };

  environment.systemPackages = with pkgs; hostMeta.extraPackages;
}
