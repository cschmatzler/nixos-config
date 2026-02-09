{inputs}: final: prev: let
	version = "0.5.1";
in {
	openusage =
		prev.rustPlatform.buildRustPackage (finalAttrs: {
				pname = "openusage";
				inherit version;

				src = inputs.openusage;

				cargoRoot = "src-tauri";
				cargoLock = {
					lockFile = "${inputs.openusage}/src-tauri/Cargo.lock";
					outputHashes = {
						"tauri-nspanel-2.1.0" = "sha256-PLACEHOLDER";
						"tauri-plugin-aptabase-1.0.0" = "sha256-PLACEHOLDER";
					};
				};
				buildAndTestSubdir = finalAttrs.cargoRoot;

				node_modules =
					prev.stdenv.mkDerivation {
						inherit (finalAttrs) src version;
						pname = "${finalAttrs.pname}-node_modules";

						impureEnvVars =
							prev.lib.fetchers.proxyImpureEnvVars
							++ [
								"GIT_PROXY_COMMAND"
								"SOCKS_SERVER"
							];

						nativeBuildInputs = [
							prev.bun
							prev.writableTmpDirAsHomeHook
						];

						dontConfigure = true;
						dontFixup = true;
						dontPatchShebangs = true;

						buildPhase = ''
							runHook preBuild

							export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

							bun install \
								--no-progress \
								--frozen-lockfile \
								--ignore-scripts

							runHook postBuild
						'';

						installPhase = ''
							runHook preInstall
							cp -R ./node_modules $out
							runHook postInstall
						'';

						outputHash = "sha256-PLACEHOLDER";
						outputHashMode = "recursive";
					};

				nativeBuildInputs = [
					prev.cargo-tauri.hook
					prev.rustPlatform.bindgenHook
					prev.bun
					prev.nodejs
					prev.pkg-config
					prev.makeBinaryWrapper
				];

				buildInputs =
					prev.lib.optionals prev.stdenv.isDarwin (
						with prev.darwin.apple_sdk.frameworks; [
							AppKit
							CoreFoundation
							CoreServices
							Security
							WebKit
						]
					);

				# Disable updater artifact generation — we don't have signing keys.
				tauriConf = builtins.toJSON {bundle.createUpdaterArtifacts = false;};
				passAsFile = ["tauriConf"];
				preBuild = ''
					tauriBuildFlags+=(
						"--config"
						"$tauriConfPath"
					)
				'';

				configurePhase = ''
					runHook preConfigure

					# Copy pre-fetched node_modules
					cp -R ${finalAttrs.node_modules} node_modules/
					chmod -R u+rw node_modules
					chmod -R u+x node_modules/.bin
					patchShebangs node_modules

					export HOME=$TMPDIR
					export PATH="$PWD/node_modules/.bin:$PATH"

					# Bundle plugins (copy from plugins/ to src-tauri/resources/bundled_plugins/)
					${prev.nodejs}/bin/node copy-bundled.cjs

					runHook postConfigure
				'';

				env = {
					OPENSSL_NO_VENDOR = true;
				};

				doCheck = false;

				postInstall =
					prev.lib.optionalString prev.stdenv.isDarwin ''
						makeWrapper $out/Applications/OpenUsage.app/Contents/MacOS/OpenUsage $out/bin/openusage
					'';

				meta = {
					description = "Track all your AI coding subscriptions in one place";
					homepage = "https://github.com/robinebers/openusage";
					license = prev.lib.licenses.mit;
					platforms = prev.lib.platforms.darwin;
					mainProgram = "openusage";
				};
			});
}
