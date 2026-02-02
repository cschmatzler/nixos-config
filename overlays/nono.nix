{inputs}: final: prev: let
	manifest = (prev.lib.importTOML "${inputs.nono}/Cargo.toml").package;
in {
	nono = prev.rustPlatform.buildRustPackage {
		pname = manifest.name;
		version = manifest.version;

		cargoLock.lockFile = "${inputs.nono}/Cargo.lock";

		src = inputs.nono;

		nativeBuildInputs = with prev; [pkg-config];
		buildInputs = with prev; [openssl dbus];
		OPENSSL_NO_VENDOR = 1;

		doCheck = false;
	};
}
