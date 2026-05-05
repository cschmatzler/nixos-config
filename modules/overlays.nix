{inputs, ...}: let
	buildFixupOverlays = [
		# direnv (Go 1.26 on darwin disables cgo, but direnv forces external linking)
		(final: prev:
				prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
					direnv =
						prev.direnv.overrideAttrs (old: {
								env =
									(old.env or {})
									// {
										CGO_ENABLED = 1;
									};
							});
				})
		# ast-grep (test_scan_invalid_rule_id fails on darwin in sandbox)
		(import ./_overlays/ast-grep.nix {inherit inputs;})
	];

	toolOverlays = [
		(import ./_overlays/himalaya.nix {inherit inputs;})
		(import ./_overlays/fallow.nix {inherit inputs;})
		(import ./_overlays/jj-ryu.nix {inherit inputs;})
		(import ./_overlays/cog-cli.nix {inherit inputs;})
		(import ./_overlays/hunkdiff.nix {inherit inputs;})
		# jj-starship passes through upstream overlay
		(import ./_overlays/jj-starship.nix {inherit inputs;})
		(import ./_overlays/zjstatus.nix {inherit inputs;})
	];

	overlays = buildFixupOverlays ++ toolOverlays;
in {
	den.default.nixos.nixpkgs.overlays = overlays;
	den.default.darwin.nixpkgs.overlays = overlays;

	flake.overlays.default = final: prev:
		builtins.foldl' (
			acc: overlay: acc // (overlay final (prev // acc))
		) {}
		overlays;
}
