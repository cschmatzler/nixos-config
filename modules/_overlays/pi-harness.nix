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
					hash = "sha256-WLbMkXERpInK/cUoRqUewwd1R6uXC/ZFDtg5wPSQJd0=";
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
