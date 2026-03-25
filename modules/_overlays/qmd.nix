{inputs, ...}: final: prev: {
	qmd =
		prev.buildNpmPackage rec {
			pname = "qmd";
			version = "2.0.1";
			src = inputs.qmd;
			npmDepsHash = "sha256-ODpDkCQwkjqf9X5EfKmnCP4z4AjC6O/lS/zJKBs/46I=";

			nativeBuildInputs = [
				prev.makeWrapper
				prev.python3
				prev.pkg-config
				prev.cmake
			];
			buildInputs = [prev.sqlite];
			dontConfigure = true;

			postPatch = ''
				cp ${./qmd-package-lock.json} package-lock.json
			'';

			npmBuildScript = "build";
			dontNpmPrune = true;

			installPhase = ''
				runHook preInstall
				mkdir -p $out/lib/node_modules/qmd $out/bin
				cp -r bin dist node_modules package.json package-lock.json LICENSE CHANGELOG.md $out/lib/node_modules/qmd/
				makeWrapper ${prev.nodejs}/bin/node $out/bin/qmd \
					--add-flags $out/lib/node_modules/qmd/dist/cli/qmd.js \
					--set LD_LIBRARY_PATH ${prev.lib.makeLibraryPath [prev.sqlite]}
				runHook postInstall
			'';

			meta = with prev.lib; {
				description = "On-device search engine for markdown notes, meeting transcripts, and knowledge bases";
				homepage = "https://github.com/tobi/qmd";
				license = licenses.mit;
				mainProgram = "qmd";
				platforms = platforms.unix;
			};
		};
}
