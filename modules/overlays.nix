{inputs, ...}: let
	overlays = [
		# himalaya
		(final: prev: {
				himalaya = inputs.himalaya.packages.${prev.stdenv.hostPlatform.system}.default;
			})
		# jj-ryu (uses build-rust-package helper)
		(final: prev: {
				jj-ryu =
					import ./_lib/build-rust-package.nix {
						inherit inputs prev;
						input = inputs.jj-ryu;
					};
			})
		# jj-starship (passes through upstream overlay)
		inputs.jj-starship.overlays.default
		# zjstatus
		(final: prev: {
				zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
			})
		# tuicr
		(final: prev: {
				tuicr = inputs.tuicr.defaultPackage.${prev.stdenv.hostPlatform.system};
			})
	];
in {
	den.default.nixos.nixpkgs.overlays = overlays;
	den.default.darwin.nixpkgs.overlays = overlays;
}
