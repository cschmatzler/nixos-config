{inputs, ...}: final: prev: let
	version = "0.24.0";
	srcs = {
		x86_64-linux =
			prev.fetchurl {
				url = "https://github.com/trycog/cog-cli/releases/download/v${version}/cog-linux-x86_64.tar.gz";
				hash = "sha256-9Ka7rPIlWtLVxRg9yNQCNz16AE4j0zGf2TW7xBXrksM=";
			};
		aarch64-darwin =
			prev.fetchurl {
				url = "https://github.com/trycog/cog-cli/releases/download/v${version}/cog-darwin-arm64.tar.gz";
				hash = "sha256-YNONHRmPGDhJeF+7rcWmrjqktYpi4b6bLl+M7IEFDtU=";
			};
	};
in {
	cog-cli =
		prev.stdenvNoCC.mkDerivation {
			pname = "cog-cli";
			inherit version;
			src =
				srcs.${prev.stdenv.hostPlatform.system}
				or (throw "Unsupported system for cog-cli: ${prev.stdenv.hostPlatform.system}");

			dontUnpack = true;
			dontConfigure = true;
			dontBuild = true;

			installPhase = ''
				runHook preInstall
				tar -xzf "$src"
				install -Dm755 cog "$out/bin/cog"
				runHook postInstall
			'';

			meta = with prev.lib; {
				description = "Memory, code intelligence, and debugging for AI agents";
				homepage = "https://github.com/trycog/cog-cli";
				license = licenses.mit;
				mainProgram = "cog";
				platforms = builtins.attrNames srcs;
				sourceProvenance = [sourceTypes.binaryNativeCode];
			};
		};
}
