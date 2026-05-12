{inputs, ...}: let
	toolOverlays = [
		(import ./_overlays/himalaya.nix {inherit inputs;})
		(import ./_overlays/fallow.nix {inherit inputs;})
		(import ./_overlays/hunkdiff.nix {inherit inputs;})
		(import ./_overlays/zjstatus.nix {inherit inputs;})
	];

	overlays = toolOverlays;
in {
	den.default.nixos.nixpkgs.overlays = overlays;
	den.default.darwin.nixpkgs.overlays = overlays;

	flake.overlays.default = final: prev:
		builtins.foldl' (
			acc: overlay: acc // (overlay final (prev // acc))
		) {}
		overlays;
}
