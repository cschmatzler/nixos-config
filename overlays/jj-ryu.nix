{inputs}: final: prev: let
	manifest = (prev.lib.importTOML "${inputs.jj-ryu}/Cargo.toml").package;
in {
	jj-ryu =
		prev.rustPlatform.buildRustPackage {
			pname = manifest.name;
			version = manifest.version;

			cargoLock.lockFile = "${inputs.jj-ryu}/Cargo.lock";

			src = inputs.jj-ryu;

			nativeBuildInputs = [prev.pkg-config];
			buildInputs = [prev.openssl];
			OPENSSL_NO_VENDOR = 1;

			doCheck = false;
		};
}
