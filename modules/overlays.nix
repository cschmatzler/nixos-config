{inputs, ...}: let
	overlays = [
		# himalaya
		(import ./_overlays/himalaya.nix {inherit inputs;})
		# ast-grep (test_scan_invalid_rule_id fails on darwin in sandbox)
		(import ./_overlays/ast-grep.nix {inherit inputs;})
		# jj-ryu
		(import ./_overlays/jj-ryu.nix {inherit inputs;})
		# cog-cli
		(import ./_overlays/cog-cli.nix {inherit inputs;})
		# pi-agent-stuff (mitsuhiko)
		(import ./_overlays/pi-agent-stuff.nix {inherit inputs;})
		# pi-harness (aliou)
		(import ./_overlays/pi-harness.nix {inherit inputs;})
		# pi-mcp-adapter
		(import ./_overlays/pi-mcp-adapter.nix {inherit inputs;})
		# jj-starship (passes through upstream overlay)
		(import ./_overlays/jj-starship.nix {inherit inputs;})
		# zjstatus
		(import ./_overlays/zjstatus.nix {inherit inputs;})
	];
in {
	den.default.nixos.nixpkgs.overlays = overlays;
	den.default.darwin.nixpkgs.overlays = overlays;

	flake.overlays.default = final: prev:
		builtins.foldl' (
			acc: overlay: acc // (overlay final (prev // acc))
		) {}
		overlays;
}
