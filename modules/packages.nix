{pkgs, ...}:
with pkgs; [
  age
  alejandra
  delta
  docker
  docker-compose
  fastfetch
  fd
  fzf
  gh
  git
  gnupg
  htop
  hyperfine
  iosevka
  jq
  killall
  nurl
  opencode
  openssh
  postgresql_17
  prettier
  sd
  sops
  sqlite
  tree
  tree-sitter
  unzip
  vivid
  zip
  (callPackage ./bin/open-project.nix {})
]
