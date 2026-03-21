{inputs, ...}: let
	overlays = [
		# himalaya
		(final: prev: {
				himalaya = inputs.himalaya.packages.${prev.stdenv.hostPlatform.system}.default;
			})
		# ast-grep (test_scan_invalid_rule_id fails on darwin in sandbox)
		(final: prev: {
				ast-grep =
					prev.ast-grep.overrideAttrs (old: {
							doCheck = false;
						});
			})
		# jj-ryu
		(final: prev: let
				naersk-lib = prev.callPackage inputs.naersk {};
				manifest = (prev.lib.importTOML "${inputs.jj-ryu}/Cargo.toml").package;
			in {
				jj-ryu =
					naersk-lib.buildPackage {
						pname = manifest.name;
						version = manifest.version;
						src = inputs.jj-ryu;
						nativeBuildInputs = [prev.pkg-config];
						buildInputs = [prev.openssl];
						OPENSSL_NO_VENDOR = 1;
						doCheck = false;
					};
			})

		# cog-cli
		(final: prev: let
				version = "0.21.0";
				srcs = {
					x86_64-linux =
						prev.fetchurl {
							url = "https://github.com/trycog/cog-cli/releases/download/v${version}/cog-linux-x86_64.tar.gz";
							hash = "sha256-3+VygNnj9mEaAFDAJp1KvDOyGglec4MRBlejbcbp4rI=";
						};
					aarch64-darwin =
						prev.fetchurl {
							url = "https://github.com/trycog/cog-cli/releases/download/v${version}/cog-darwin-arm64.tar.gz";
							hash = "sha256-kUihpA+kjrDt18t4nkLWW2yRzz76A0CvxE4NNaldLH4=";
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
			})
		# jj-starship (passes through upstream overlay)
		inputs.jj-starship.overlays.default
		# zjstatus
		(final: prev: {
				zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
			})
	];
in {
	den.default.nixos.nixpkgs.overlays = overlays;
	den.default.darwin.nixpkgs.overlays = overlays;

	flake.overlays.default = final: prev:
		builtins.foldl' (
			acc: overlay: acc // (overlay final (prev // acc))
		) {}
		overlays;
}
