{inputs}: final: prev: {
	lumen = inputs.lumen.packages.${prev.stdenv.hostPlatform.system}.default;
}
