{pkgs, inputs, ...}:
with pkgs; [
	(inputs.beads.packages.${pkgs.system}.default.overrideAttrs (old: {
		vendorHash = "sha256-jpaeKw5dbZuhV9Z18aQ9tDMS/Eo7HaXiZefm26UlPyI=";
	}))
	(callPackage ./bin/open-project.nix {})
	age
	alejandra
	ast-grep
	bun
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
