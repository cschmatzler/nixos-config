{inputs}: final: prev: {
	lumen =
		import ../lib/build-rust-package.nix {
			inherit prev;
			input = inputs.lumen;
		};
}
