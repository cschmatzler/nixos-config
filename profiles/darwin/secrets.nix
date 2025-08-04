{
  config,
  pkgs,
  agenix,
  secrets,
  user,
  ...
}:
{
  age.identityPaths = [
    "/Users/${user}/.ssh/id_ed25519"
  ];
}
