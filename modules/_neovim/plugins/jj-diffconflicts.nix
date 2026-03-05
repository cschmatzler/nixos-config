{pkgs, ...}: {
	programs.nixvim.extraPlugins = [
		(pkgs.vimUtils.buildVimPlugin {
				name = "jj-diffconflicts";
				src =
					pkgs.fetchFromGitHub {
						owner = "rafikdraoui";
						repo = "jj-diffconflicts";
						rev = "main";
						hash = "sha256-nzjRWHrE2jIcaDoPbixzpvflrtLhPZrihOEQWwqqU0s=";
					};
			})
	];
}
