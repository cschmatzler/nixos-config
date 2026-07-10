{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    checks.lint =
      pkgs.runCommand "nix-config-lint" {
        nativeBuildInputs = with pkgs; [
          alejandra
          bash
          deadnix
          findutils
          statix
        ];
      } ''
        export HOME="$TMPDIR"
        cd ${inputs.self}
        alejandra --check .
        deadnix --fail .
        statix check .
        find apps -type f -print0 | xargs -0 -n1 bash -n
        touch "$out"
      '';
  };
}
