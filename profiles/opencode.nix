{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			theme = "catppuccin";
			instructions = [
				"CLAUDE.md"
				"AGENT.md"
				"AGENTS.md"
			];
			formatter = {
				mix = {
					disabled = true;
				};
			};
		};
	};
	home.sessionVariables = {
		OPENCODE_EXPERIMENTAL_EXA = "true";
	};
}
