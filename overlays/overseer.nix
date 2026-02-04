{inputs}: final: prev: let
	manifest = (prev.lib.importTOML "${inputs.overseer}/overseer/Cargo.toml").package;
in {
	overseer = prev.rustPlatform.buildRustPackage {
		pname = manifest.name;
		version = manifest.version;

		cargoLock.lockFile = "${inputs.overseer}/overseer/Cargo.lock";

		src = "${inputs.overseer}/overseer";

		nativeBuildInputs = with prev; [
			pkg-config
		];

		buildInputs = with prev; [
			openssl
		];

		OPENSSL_NO_VENDOR = 1;

		doCheck = false;
	};
}
