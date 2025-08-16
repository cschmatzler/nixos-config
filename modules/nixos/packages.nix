{pkgs}:
with pkgs; [
  gcc15
  (callPackage ../../bin/open-project.nix {})
]
