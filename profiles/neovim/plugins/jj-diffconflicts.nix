{pkgs, ...}: {
	programs.nixvim.extraPlugins = [
		(pkgs.vimUtils.buildVimPlugin {
				name = "jj-diffconflicts";
				src =
					pkgs.fetchFromGitHub {
						owner = "rafikdraoui";
						repo = "jj-diffconflicts";
						rev = "main";
						hash = "sha256-hvMXpslucywVYA9Sdxx6IcXQXYcYNWK8s9jr+KtStdI=";
					};
			})
	];
}
