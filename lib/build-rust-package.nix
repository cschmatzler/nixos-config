{
	input,
	prev,
}: let
	manifest = (prev.lib.importTOML "${input}/Cargo.toml").package;
in
	prev.rustPlatform.buildRustPackage {
		pname = manifest.name;
		version = manifest.version;

		cargoLock.lockFile = "${input}/Cargo.lock";

		src = input;

		nativeBuildInputs = [prev.pkg-config];
		buildInputs = [prev.openssl];
		OPENSSL_NO_VENDOR = 1;

		doCheck = false;
	}
