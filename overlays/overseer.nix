{inputs}: final: prev: let
	manifest = (prev.lib.importTOML "${inputs.overseer}/overseer/Cargo.toml").package;

	overseer-cli =
		prev.rustPlatform.buildRustPackage {
			pname = "overseer-cli";
			version = manifest.version;

			cargoLock.lockFile = "${inputs.overseer}/overseer/Cargo.lock";

			src = "${inputs.overseer}/overseer";

			nativeBuildInputs = with prev; [
				pkg-config
			];

			buildInputs = with prev; [
				openssl
			];

			OPENSSL_NO_VENDOR = 1;

			doCheck = false;
		};

	overseer-host =
		prev.buildNpmPackage {
			pname = "overseer-host";
			version = manifest.version;

			src = "${inputs.overseer}/host";

			npmDepsHash = "sha256-WIjx6N8vnH3C6Kxn4tiryi3bM0xnov5ok2k9XrndIS0=";

			buildPhase = ''
				runHook preBuild
				npm run build
				runHook postBuild
			'';

			installPhase = ''
				runHook preInstall
				mkdir -p $out
				cp -r dist $out/
				cp -r node_modules $out/
				cp package.json $out/
				runHook postInstall
			'';
		};

	overseer-ui =
		prev.buildNpmPackage {
			pname = "overseer-ui";
			version = manifest.version;

			src = "${inputs.overseer}/ui";

			npmDepsHash = "sha256-krOsSd8OAPsdCOCf1bcz9c/Myj6jpHOkaD/l+R7PQpY=";

			buildPhase = ''
				runHook preBuild
				npm run build
				runHook postBuild
			'';

			installPhase = ''
				runHook preInstall
				mkdir -p $out
				cp -r dist $out/
				runHook postInstall
			'';
		};
in {
	# The CLI looks for host/dist/index.js and ui/dist relative to the binary
	# Using paths like: exe_dir.join("../@dmmulroy/overseer/host/dist/index.js")
	# So we create: bin/os and @dmmulroy/overseer/host/dist/index.js
	overseer =
		prev.runCommand "overseer-${manifest.version}" {
			nativeBuildInputs = [prev.makeWrapper];
		} ''
			# Create npm-like structure that the CLI expects
			mkdir -p $out/bin
			mkdir -p $out/@dmmulroy/overseer/host
			mkdir -p $out/@dmmulroy/overseer/ui

			# Copy host files
			cp -r ${overseer-host}/dist $out/@dmmulroy/overseer/host/
			cp -r ${overseer-host}/node_modules $out/@dmmulroy/overseer/host/
			cp ${overseer-host}/package.json $out/@dmmulroy/overseer/host/

			# Copy UI files
			cp -r ${overseer-ui}/dist $out/@dmmulroy/overseer/ui/

			# Copy CLI binary
			cp ${overseer-cli}/bin/os $out/bin/os

			# Make wrapper that ensures node is available
			wrapProgram $out/bin/os \
				--prefix PATH : ${prev.nodejs}/bin
		'';
}
