{inputs}: let
	dir = builtins.readDir ./.;
	overlayNames =
		builtins.sort builtins.lessThan (builtins.filter (
				name:
					name
					!= "default.nix"
					&& dir.${name} == "regular"
					&& builtins.match ".*\\.nix" name != null
			) (builtins.attrNames dir));
	overlayPath = name:
		builtins.toPath "${builtins.toString ./.}/${name}";
	loadOverlay = name: let
		overlayModule = import (overlayPath name);
	in
		overlayModule {inherit inputs;};
in
	map loadOverlay overlayNames
