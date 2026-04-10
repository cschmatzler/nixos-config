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
					fetcherVersion = 3;
					hash = "sha256-Y1lS51HT4cQ2h634SRd5RQSrODXz86L9J/89rQK/XOE=";
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
