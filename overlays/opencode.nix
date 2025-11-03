{inputs}: final: prev: {
  # Override the fixed-output hash for the nested derivation
  # opencode-src-with-node_modules on x86_64-linux
  opencode = prev.opencode.overrideAttrs (old: {
    "src-with-node_modules" = old."src-with-node_modules".overrideAttrs (o2: {
      outputHash = if prev.stdenv.hostPlatform.system == "x86_64-linux"
        then "sha256-eML3T1FQ5ziRWIuLDirnHvxLEKMtKDy3op47JnfFU6w="
        else o2.outputHash;
    });
  });
}

