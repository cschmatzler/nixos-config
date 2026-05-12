{inputs, ...}: final: prev: let
	vitePlusOverlay = inputs.nix-vite-plus.overlays.default final prev;
in
	vitePlusOverlay
	// {
		vite-plus =
			vitePlusOverlay.vite-plus.overrideAttrs (_: {
					doInstallCheck = false;
				});
	}
