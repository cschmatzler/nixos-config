{inputs}: final: prev: {
	jj-ryu =
		import ../lib/build-rust-package.nix {
			inherit prev;
			input = inputs.jj-ryu;
		};
}
