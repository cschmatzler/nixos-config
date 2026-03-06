{inputs, ...}: {
	perSystem = {
		pkgs,
		system,
		...
	}: let
		descriptions = {
			apply = "Build and apply configuration";
			build = "Build configuration";
			rollback = "Rollback to previous generation";
			update = "Update flake inputs and regenerate flake.nix";
		};
		mkPlatformApp = name: {
			type = "app";
			program = "${(pkgs.writeShellScriptBin name ''
					PATH=${pkgs.git}/bin:$PATH
					exec ${inputs.self}/apps/${system}/${name} "$@"
				'')}/bin/${name}";
			meta.description = descriptions.${name};
		};
		mkSharedApp = name: {
			type = "app";
			program = "${(pkgs.writeShellScriptBin name ''
					PATH=${pkgs.git}/bin:$PATH
					exec ${inputs.self}/apps/${name} "$@"
				'')}/bin/${name}";
			meta.description = descriptions.${name};
		};
		platformAppNames = ["build" "rollback" "update"];
		sharedAppNames = ["apply"];
	in {
		apps =
			pkgs.lib.genAttrs platformAppNames mkPlatformApp
			// pkgs.lib.genAttrs sharedAppNames mkSharedApp
			// {
				deploy = {
					type = "app";
					program = "${inputs.deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
					meta.description = "Deploy to NixOS hosts via deploy-rs";
				};
			};
	};
}
