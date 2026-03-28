{...}: let
	local = import ../../_lib/local.nix;
in {
	den.aspects.user-personal.homeManager = {
		programs.git.settings.user.email = local.user.emails.personal;
	};
}
