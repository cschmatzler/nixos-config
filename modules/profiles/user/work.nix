_: let
  local = import ../../_lib/local.nix;
in {
  den.aspects.user-work.homeManager = {
    programs.git.settings.user.email = local.user.emails.work;
  };
}
