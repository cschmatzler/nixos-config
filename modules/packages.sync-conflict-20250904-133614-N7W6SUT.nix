{pkgs, ...}:
with pkgs; [
  (callPackage ./bin/open-project.nix {})
  age
  alejandra
  nodejs_24
  pnpm
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
