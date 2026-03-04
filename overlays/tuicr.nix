{inputs}: final: prev: {
	tuicr = inputs.tuicr.packages.${prev.stdenv.hostPlatform.system}.default;
}
