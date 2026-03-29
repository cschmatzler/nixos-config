{inputs, ...}: final: prev: {
	pi-harness =
		prev.stdenvNoCC.mkDerivation {
			pname = "pi-harness";
			version = "0.0.0";
			src = inputs.pi-harness;

			pnpmDeps =
				prev.fetchPnpmDeps {
					pname = "pi-harness";
					version = "0.0.0";
					src = inputs.pi-harness;
					pnpm = prev.pnpm_10;
					fetcherVersion = 1;
					hash = "sha256-l85j3MH/uott+6Cbo9r3w8jojdlikjGf26l4Q1qa43g=";
				};

			nativeBuildInputs = [
				prev.pnpmConfigHook
				prev.pnpm_10
				prev.nodejs
			];

			dontBuild = true;

			installPhase = ''
				runHook preInstall
				mkdir -p $out/lib/node_modules/@aliou/pi-harness
				cp -r . $out/lib/node_modules/@aliou/pi-harness
				runHook postInstall
			'';
		};
}
