{inputs}: final: prev: let
  manifest = (prev.lib.importTOML "${inputs.nono}/crates/nono-cli/Cargo.toml").package;
in {
  nono = prev.rustPlatform.buildRustPackage {
    pname = "nono";
    inherit (manifest) version;

    src = inputs.nono;
    cargoLock.lockFile = "${inputs.nono}/Cargo.lock";
    cargoBuildFlags = [
      "-p"
      manifest.name
    ];

    nativeBuildInputs = with prev; [
      pkg-config
      cmake
      perl
    ];
    buildInputs = with prev;
      [openssl]
      ++ lib.optionals stdenv.isLinux [dbus];

    OPENSSL_NO_VENDOR = 1;
    doCheck = false;
  };
}
