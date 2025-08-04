{
  config,
  pkgs,
  agenix,
  secrets,
  ...
}:

let
  user = "cschmatzler";
in
{
  age.identityPaths = [
    "/Users/${user}/.ssh/id_ed25519"
  ];
}
