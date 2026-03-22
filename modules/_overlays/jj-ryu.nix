{inputs, ...}: final: prev: let
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
}
