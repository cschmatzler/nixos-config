{pkgs, ...}: {
	programs.nixvim.extraPlugins = [
		(pkgs.vimUtils.buildVimPlugin {
				name = "jj-diffconflicts";
				src =
					pkgs.fetchFromGitHub {
						owner = "rafikdraoui";
						repo = "jj-diffconflicts";
						rev = "main";
						hash = "sha256-tyRTw3ENV7zlZF3Dp9zO4Huu02K5uyXb3brAJCW4w2M=";
					};
			})
	];
}
