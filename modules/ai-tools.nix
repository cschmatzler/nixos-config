{den, ...}: let
	theme = (import ./_lib/theme.nix).catppuccinLatte;
in {
	den.aspects.ai-tools = {
		includes = [
			den.aspects.ai-api-key
			den.aspects.pi
			den.aspects.ynab
		];

		homeManager = {inputs', ...}: {
			programs.opencode = {
				enable = true;
				package = inputs'.llm-agents.packages.opencode;
				settings.mcp = {
					opensrc = {
						type = "local";
						command = [
							"npx"
							"-y"
							"opensrc-mcp"
						];
						enabled = true;
					};
					executor = {
						type = "remote";
						url = "https://executor.sh/mcp";
						enabled = true;
					};
				};
				tui.theme = theme.opencodeName;
			};
		};
	};
}
