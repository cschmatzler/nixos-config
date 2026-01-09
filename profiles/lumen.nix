{pkgs, ...}: {
	home.packages = with pkgs; [
		lumen
	];
}
