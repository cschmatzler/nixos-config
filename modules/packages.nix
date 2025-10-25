{pkgs, ...}:
with pkgs; [
  (callPackage ./bin/open-project.nix {})
  age
  alejandra
  amp-cli
  ast-grep
  codex
  delta
  devenv
  dig
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
  jq
  killall
  lsof
  nurl
  openssh
  postgresql_17
  sd
  sops
  sqlite
  tokei
  tree
  tree-sitter
  unzip
  vivid
  zip
]
