{
	pkgs,
	theme,
}: {
	command = "${pkgs.fish}/bin/fish";
	theme = theme.ghosttyName;
	window-padding-x = 12;
	window-padding-y = 3;
	window-padding-balance = true;
	font-family = "FiraCode Nerd Font";
	font-size = 17.5;
	cursor-style = "block";
	mouse-hide-while-typing = true;
	mouse-scroll-multiplier = 1.25;
	shell-integration = "none";
	shell-integration-features = "no-cursor";
	clipboard-read = "allow";
	clipboard-write = "allow";
}
