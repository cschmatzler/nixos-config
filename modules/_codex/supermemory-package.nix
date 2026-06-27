{pkgs}: let
	version = "1.0.5";
in
	pkgs.stdenvNoCC.mkDerivation {
		pname = "codex-supermemory";
		inherit version;

		src = ./supermemory;

		nativeBuildInputs = [
			pkgs.makeWrapper
		];

		dontBuild = true;
		dontUnpack = true;

		installPhase = ''
			runHook preInstall

			mkdir -p "$out/bin" "$out/share/codex-supermemory"
			cp -R "$src"/. "$out/share/codex-supermemory/"
			chmod +x \
				"$out/share/codex-supermemory/cli.js" \
				"$out/share/codex-supermemory/hooks/flush.js" \
				"$out/share/codex-supermemory/hooks/recall.js" \
				"$out/share/codex-supermemory/skills/forget-memory.js" \
				"$out/share/codex-supermemory/skills/login.js" \
				"$out/share/codex-supermemory/skills/save-memory.js" \
				"$out/share/codex-supermemory/skills/search-memory.js"

			makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/codex-supermemory" \
				--add-flags "$out/share/codex-supermemory/cli.js"

			runHook postInstall
		'';

		meta = {
			description = "Persistent memory for OpenAI Codex CLI powered by Supermemory";
			homepage = "https://www.npmjs.com/package/codex-supermemory";
			license = pkgs.lib.licenses.mit;
			mainProgram = "codex-supermemory";
			platforms = pkgs.lib.platforms.all;
		};
	}
