{inputs}: final: prev: {
	jj-ryu =
		import ../lib/build-rust-package.nix {
			inherit inputs prev;
			input = inputs.jj-ryu;
		};
}
