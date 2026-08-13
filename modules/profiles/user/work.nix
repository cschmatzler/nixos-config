_: {
  den.aspects.user-work.homeManager = {
    programs.git.settings.user.email = (import ../../_lib/local.nix).user.emails.work;
  };
}
