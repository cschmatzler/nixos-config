{inputs, ...}: final: prev: let
	toolchain = inputs.fenix.packages.${prev.stdenv.hostPlatform.system}.stable.defaultToolchain;
	naersk-lib =
		prev.callPackage inputs.naersk {
			cargo = toolchain;
			rustc = toolchain;
		};
	manifest = prev.lib.importTOML "${inputs.fallow}/Cargo.toml";
in {
	fallow =
		naersk-lib.buildPackage rec {
			pname = "fallow";
			version = manifest.workspace.package.version;
			name = pname;
			src = inputs.fallow;
			cargoBuildOptions = options: options ++ ["-p" "fallow-cli"];
			doCheck = false;

			meta = with prev.lib; {
				description = "Codebase intelligence for TypeScript and JavaScript";
				homepage = "https://github.com/fallow-rs/fallow";
				license = licenses.mit;
				mainProgram = "fallow";
			};
		};
}
