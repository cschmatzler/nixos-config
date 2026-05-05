{inputs, ...}: final: prev: let
	version = "0.10.0";
	hunkSrc =
		prev.fetchurl {
			url = "https://registry.npmjs.org/hunkdiff/-/hunkdiff-${version}.tgz";
			hash = "sha512-GfUYNCzEnZ0OTdg340YRFbW1SvvwgRMyQmn44t2GKoSjYqiXGaDCeOG66fpIzU8WRdbUi2uzdGIVkEsCps8TeA==";
		};
	prebuilt = {
		x86_64-linux = {
			packageName = "hunkdiff-linux-x64";
			binary = "hunk";
			hash = "sha512-me3Pl6Tqb46yoZP930iCUdE3pE5lDOtfsWUcCZXqEpsg0WPbW6PjO6tjX7MRnkLFPacPDrqfPZpEHr2bxK0X9A==";
		};
		aarch64-linux = {
			packageName = "hunkdiff-linux-arm64";
			binary = "hunk";
			hash = "sha512-h3yY1cxEmer3StCppvQ4kZyK10971t6dMO76jMnWNhREWML2H2hCiPrNw5Yjx0tI0AyI1P4D3guNCcvylLmO4A==";
		};
		x86_64-darwin = {
			packageName = "hunkdiff-darwin-x64";
			binary = "hunk";
			hash = "sha512-5sVwIN7OQ4x6/K1TfP4n0wUZinL9nPKmbZ/oHJWhMD6FScGuOOYYZQtN+q2j3ahzlu36Iio7OXajuyQZulwU4A==";
		};
		aarch64-darwin = {
			packageName = "hunkdiff-darwin-arm64";
			binary = "hunk";
			hash = "sha512-oJALanUcIFp19LQbTTNKEk/RA0QIeeqwXzUciTzBlze1IA5GPe+rq+OLy66fFUA5tiO6qj6sXf1UqK9cL8o0Mw==";
		};
	};
	platform =
		prebuilt.${prev.stdenv.hostPlatform.system}
		or (throw "Unsupported system for hunkdiff: ${prev.stdenv.hostPlatform.system}");
	prebuiltSrc =
		prev.fetchurl {
			url = "https://registry.npmjs.org/${platform.packageName}/-/${platform.packageName}-${version}.tgz";
			inherit (platform) hash;
		};
	hunkPackage =
		prev.stdenvNoCC.mkDerivation {
			pname = "hunkdiff-package";
			inherit version;
			src = hunkSrc;
			installPhase = ''
				runHook preInstall
				mkdir -p "$out"
				tar -xzf "$src" --strip-components=1 -C "$out"
				runHook postInstall
			'';
		};
	hunkBinary =
		prev.stdenvNoCC.mkDerivation {
			pname = platform.packageName;
			inherit version;
			src = prebuiltSrc;
			installPhase = ''
				runHook preInstall
				mkdir -p "$out"
				tar -xzf "$src" --strip-components=1 -C "$out"
				chmod 0755 "$out/bin/${platform.binary}"
				runHook postInstall
			'';
		};
	runHunk =
		prev.writeShellScript "hunk-run" ''
			if [ "$#" -eq 2 ] && [ "$1" = skill ] && [ "$2" = path ]; then
				printf '%s\n' '${hunkPackage}/skills/hunk-review/SKILL.md'
				exit 0
			fi

			exec ${hunkBinary}/bin/${platform.binary} "$@"
		'';
	meta = with prev.lib; {
		description = "Desktop-inspired terminal diff viewer for understanding agent-authored changesets";
		homepage = "https://github.com/modem-dev/hunk";
		license = licenses.mit;
		mainProgram = "hunk";
		platforms = builtins.attrNames prebuilt;
		sourceProvenance = [sourceTypes.binaryNativeCode];
	};
in {
	hunkdiff =
		if prev.stdenv.hostPlatform.isLinux
		then
			prev.buildFHSEnv {
				name = "hunk";
				inherit meta;
				runScript = runHunk;
			}
		else
			prev.stdenvNoCC.mkDerivation {
				pname = "hunkdiff";
				inherit version meta;
				dontUnpack = true;
				dontConfigure = true;
				dontBuild = true;

				installPhase = ''
					runHook preInstall
					mkdir -p "$out/bin"
					cp ${runHunk} "$out/bin/hunk"
					runHook postInstall
				'';
			};
}
