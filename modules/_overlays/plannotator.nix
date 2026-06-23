{...}: final: prev: let
	version = "0.21.1";
	prebuilt = {
		x86_64-linux = {
			asset = "plannotator-linux-x64";
			hash = "sha256-J6TicUU4FJ8aPKQY/tgYSVVDSAwX36YQMrBz9v9DaP8=";
		};
		aarch64-linux = {
			asset = "plannotator-linux-arm64";
			hash = "sha256-MCFhVvkx6rtJA60OkQDRSJPuOM7EmENuBz8GP/Uakno=";
		};
		x86_64-darwin = {
			asset = "plannotator-darwin-x64";
			hash = "sha256-rwFTNIlWsoLpW8mkdb1kQH+u4D0ufTY3wKderZ/pMbA=";
		};
		aarch64-darwin = {
			asset = "plannotator-darwin-arm64";
			hash = "sha256-ibSF9UU42tIRzV8eLiloYMw66kM620eF7tM12+JTd68=";
		};
	};
	platform =
		prebuilt.${prev.stdenv.hostPlatform.system}
		or (throw "Unsupported system for plannotator: ${prev.stdenv.hostPlatform.system}");
in {
	plannotator =
		prev.stdenvNoCC.mkDerivation {
			pname = "plannotator";
			inherit version;

			src =
				prev.fetchurl {
					url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/${platform.asset}";
					inherit (platform) hash;
				};

			dontUnpack = true;
			dontConfigure = true;
			dontBuild = true;

			nativeBuildInputs =
				prev.lib.optionals prev.stdenv.hostPlatform.isLinux [
					prev.autoPatchelfHook
				];
			buildInputs =
				prev.lib.optionals prev.stdenv.hostPlatform.isLinux [
					prev.stdenv.cc.cc
				];

			installPhase = ''
				runHook preInstall
				mkdir -p "$out/bin"
				cp "$src" "$out/bin/plannotator"
				chmod 0755 "$out/bin/plannotator"
				runHook postInstall
			'';

			meta = with prev.lib; {
				description = "Local browser-based review surface for AI coding agents";
				homepage = "https://github.com/backnotprop/plannotator";
				license = with licenses; [mit asl20];
				mainProgram = "plannotator";
				platforms = builtins.attrNames prebuilt;
				sourceProvenance = [sourceTypes.binaryNativeCode];
			};
		};
}
