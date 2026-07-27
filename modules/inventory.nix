_: let
  local = import ./_lib/local.nix;
in {
  den.hosts = {
    aarch64-darwin.chidi.users.${local.user.name} = {};
    aarch64-darwin.janet.users.${local.user.name} = {};
    x86_64-linux.tahani.users.${local.user.name} = {};
  };
}
