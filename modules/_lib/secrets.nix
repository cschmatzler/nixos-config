_: let
  local = import ./local.nix;
in {
  mkUserBinarySecret = {
    name,
    sopsFile,
    owner ? local.user.name,
    path ? local.secretPath name,
  }: {
    inherit owner path sopsFile;
    format = "binary";
  };
}
