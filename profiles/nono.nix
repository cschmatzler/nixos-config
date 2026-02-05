{pkgs, ...}: {
	home.packages = with pkgs; [
		nono
	];
}
