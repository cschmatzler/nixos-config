{
  pkgs,
  user,
  ...
}: {
  imports = [
    ../shared.nix
  ];

  networking.hostName = "chidi";
  networking.computerName = "Chidi";

  home-manager.users.${user} = {
    programs.git.userEmail = "christoph@tuist.dev";
  };

  environment.systemPackages = with pkgs; [
    slack
  ];
}
