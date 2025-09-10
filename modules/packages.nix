{pkgs, ...}:
with pkgs; [
  (callPackage ./bin/open-project.nix {})
  age
  alejandra
  ast-grep
  codex
  delta
  devenv
  dig
  docker
  docker-compose
  fastfetch
  fd
  fira-code
  gh
  git
  gnumake
  gnupg
  htop
  hyperfine
  jjui
  jq
  killall
  lsof
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
