{inputs, ...}: final: prev: {
	himalaya = inputs.himalaya.packages.${prev.stdenv.hostPlatform.system}.default;
}
