{inputs}: final: prev: {
	neverest = inputs.neverest.packages.${prev.stdenv.hostPlatform.system}.default;
}
