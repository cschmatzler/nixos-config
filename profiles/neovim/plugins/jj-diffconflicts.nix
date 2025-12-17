{pkgs, ...}: {
	programs.nixvim.extraPlugins = [
		(pkgs.vimUtils.buildVimPlugin {
				name = "jj-diffconflicts";
				src =
					pkgs.fetchFromGitHub {
						owner = "rafikdraoui";
						repo = "jj-diffconflicts";
						rev = "main";
						hash = "sha256-FXsLSYy+eli8VArUL8ZOiPtyOk4Q8TUYwobEefZPRII=";
					};
			})
	];
}
