{inputs, ...}: {
	perSystem = {
		pkgs,
		system,
		...
	}: let
		mkApp = name: {
			type = "app";
			program = "${(pkgs.writeShellScriptBin name ''
					PATH=${pkgs.git}/bin:$PATH
					echo "Running ${name} for ${system}"
					exec ${inputs.self}/apps/${system}/${name} "$@"
				'')}/bin/${name}";
		};
		appNames = ["apply" "build" "build-switch" "rollback"];
	in {
		apps =
			pkgs.lib.genAttrs appNames mkApp
			// {
				deploy = {
					type = "app";
					program = "${inputs.deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
				};
			};
	};
}
