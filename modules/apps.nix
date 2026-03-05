{inputs, ...}: {
	perSystem = {
		pkgs,
		system,
		...
	}: let
		descriptions = {
			apply = "Build and apply configuration";
			build = "Build configuration";
			build-switch = "Build and switch configuration";
			rollback = "Rollback to previous generation";
		};
		mkApp = name: {
			type = "app";
			program = "${(pkgs.writeShellScriptBin name ''
					PATH=${pkgs.git}/bin:$PATH
					echo "Running ${name} for ${system}"
					exec ${inputs.self}/apps/${system}/${name} "$@"
				'')}/bin/${name}";
			meta.description = descriptions.${name};
		};
		appNames = ["apply" "build" "build-switch" "rollback"];
	in {
		apps =
			pkgs.lib.genAttrs appNames mkApp
			// {
				deploy = {
					type = "app";
					program = "${inputs.deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
					meta.description = "Deploy to NixOS hosts via deploy-rs";
				};
			};
	};
}
