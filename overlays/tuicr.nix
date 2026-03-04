{inputs}: final: prev: {
	tuicr = inputs.tuicr.defaultPackage.${prev.stdenv.hostPlatform.system};
}
