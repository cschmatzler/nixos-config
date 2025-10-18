{pkgs, ...}:
with pkgs; [
  (callPackage ./bin/open-project.nix {})
  age
  amp-cli
  alejandra
  ast-grep
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
