{
	inputs,
	input,
	prev,
}: let
	naersk-lib = prev.callPackage inputs.naersk {};
	manifest = (prev.lib.importTOML "${input}/Cargo.toml").package;
in
	naersk-lib.buildPackage {
		pname = manifest.name;
		version = manifest.version;

		src = input;

		nativeBuildInputs = [prev.pkg-config];
		buildInputs = [prev.openssl];
		OPENSSL_NO_VENDOR = 1;

		doCheck = false;
	}
