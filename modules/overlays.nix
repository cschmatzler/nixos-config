{inputs, ...}: let
	overlays = [
		# himalaya
		(final: prev: {
				himalaya = inputs.himalaya.packages.${prev.stdenv.hostPlatform.system}.default;
			})
		# ast-grep (test_scan_invalid_rule_id fails on darwin in sandbox)
		(final: prev: {
				ast-grep =
					prev.ast-grep.overrideAttrs (old: {
							doCheck = false;
						});
			})
		# jj-ryu
		(final: prev: let
				naersk-lib = prev.callPackage inputs.naersk {};
				manifest = (prev.lib.importTOML "${inputs.jj-ryu}/Cargo.toml").package;
			in {
				jj-ryu =
					naersk-lib.buildPackage {
						pname = manifest.name;
						version = manifest.version;
						src = inputs.jj-ryu;
						nativeBuildInputs = [prev.pkg-config];
						buildInputs = [prev.openssl];
						OPENSSL_NO_VENDOR = 1;
						doCheck = false;
					};
			})
		# nono (AI agent sandbox CLI — Cargo workspace)
		(final: prev: let
				naersk-lib = prev.callPackage inputs.naersk {};
				manifest = (prev.lib.importTOML "${inputs.nono}/crates/nono-cli/Cargo.toml").package;
			in {
				nono =
					naersk-lib.buildPackage {
						pname = manifest.name;
						version = manifest.version;
						src = inputs.nono;
						nativeBuildInputs = [prev.pkg-config prev.cmake prev.perl];
						buildInputs = [prev.openssl] ++ prev.lib.optionals prev.stdenv.isLinux [prev.dbus];
						OPENSSL_NO_VENDOR = 1;
						doCheck = false;
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

	flake.overlays.default = final: prev:
		builtins.foldl' (
			acc: overlay: acc // (overlay final (prev // acc))
		) {}
		overlays;
}
