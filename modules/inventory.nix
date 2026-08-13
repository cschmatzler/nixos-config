_:
with import ./_lib/local.nix; {
  den.hosts = {
    aarch64-darwin.chidi.users.${user.name} = {};
    aarch64-darwin.janet.users.${user.name} = {};
    x86_64-linux.tahani.users.${user.name} = {};
  };
}
