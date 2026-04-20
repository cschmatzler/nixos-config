{inputs, ...}: final: prev: let
	patchedRustPlatform =
		prev.rustPlatform
		// {
			buildRustPackage = args:
				prev.rustPlatform.buildRustPackage (
					args
					// {
						postPatch =
							(args.postPatch or "")
							+ ''
								# zlob 1.3.0 defaults to Zig's native target for host builds,
								# which can emit instructions unsupported by this machine
								# (observed as SIGILL in zlob_has_wildcards).
								# Force the non-native path so it uses rust_target_to_zig(&target).
								substituteInPlace $cargoDepsCopy/*/zlob-1.3.0/build.rs \
									--replace-fail \
										'if target == host && !target.contains("windows") {' \
										'if false {'
							'';
					}
				);
		};
in {
	vimPlugins =
		prev.vimPlugins
		// {
			fff-nvim =
				prev.callPackage "${inputs.nixpkgs}/pkgs/applications/editors/vim/plugins/non-generated/fff-nvim/default.nix" {
					rustPlatform = patchedRustPlatform;
				};
		};
}
