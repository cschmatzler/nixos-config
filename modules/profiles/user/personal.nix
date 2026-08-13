_: {
  den.aspects.user-personal.homeManager = {
    programs.git.settings.user.email = (import ../../_lib/local.nix).user.emails.personal;
  };
}
