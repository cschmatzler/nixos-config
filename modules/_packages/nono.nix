{
  cmake,
  dbus,
  lib,
  nonoSrc,
  openssl,
  perl,
  pkg-config,
  rustPlatform,
  stdenv,
}: let
  manifest = (lib.importTOML "${nonoSrc}/crates/nono-cli/Cargo.toml").package;
in
  rustPlatform.buildRustPackage {
    pname = "nono";
    inherit (manifest) version;

    src = nonoSrc;
    cargoLock.lockFile = "${nonoSrc}/Cargo.lock";
    cargoBuildFlags = [
      "-p"
      manifest.name
    ];

    nativeBuildInputs = [
      pkg-config
      cmake
      perl
    ];
    buildInputs = [openssl] ++ lib.optionals stdenv.isLinux [dbus];

    OPENSSL_NO_VENDOR = 1;
    doCheck = false;
  }
