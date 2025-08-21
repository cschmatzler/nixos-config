{pkgs, ...}:
with pkgs; [
  (callPackage ./bin/open-project.nix {})
  age
  alejandra
  delta
  docker
  docker-compose
  fastfetch
  fd
  gh
  git
  gnumake
  gnupg
  htop
  hyperfine
  iosevka
  jq
  killall
  nurl
  openssh
  postgresql_17
  sd
  sops
  sqlite
  tree
  tree-sitter
  unzip
  vivid
  zip
]
