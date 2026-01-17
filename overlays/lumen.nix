{inputs}: final: prev: let
	manifest = (prev.lib.importTOML "${inputs.lumen}/Cargo.toml").package;
in {
	lumen =
		prev.rustPlatform.buildRustPackage {
			pname = manifest.name;
			version = manifest.version;

			cargoLock.lockFile = "${inputs.lumen}/Cargo.lock";

			src = inputs.lumen;

			nativeBuildInputs = [prev.pkg-config];
			buildInputs = [prev.openssl];
			OPENSSL_NO_VENDOR = 1;

			doCheck = false;
		};
}
