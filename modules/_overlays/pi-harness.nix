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
					hash = "sha256-FgtJnmJ0/udz2A9N2DQns+a2CspMDEDk0DPUAxmCVY4=";
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
