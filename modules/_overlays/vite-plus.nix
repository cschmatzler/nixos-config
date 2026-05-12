{inputs, ...}: final: prev: let
	vitePlusOverlay = inputs.nix-vite-plus.overlays.default final prev;
in
	vitePlusOverlay
	// {
		vite-plus =
			vitePlusOverlay.vite-plus.overrideAttrs (old: {
					doInstallCheck = false;
					pnpmDeps =
						if final.stdenv.hostPlatform.isDarwin
						then
							old.pnpmDeps.override {
								pnpm = final.pnpm_10;
								hash = old.pnpmDeps.outputHash;
							}
						else old.pnpmDeps;
				});
	}
