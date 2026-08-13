_:
with import ./local.nix; {
  mkUserBinarySecret = {
    name,
    sopsFile,
    owner ? user.name,
    path ? secretPath name,
  }: {
    inherit owner path sopsFile;
    format = "binary";
  };
}
