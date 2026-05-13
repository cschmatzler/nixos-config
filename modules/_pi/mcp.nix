{
	lib,
	pkgs,
}: {
	mcpServers = {
		opensrc = {
			command = "npx";
			args = [
				"-y"
				"opensrc-mcp"
			];
			directTools = true;
			lifecycle = "eager";
		};
		executor = {
			url = "https://executor.sh/mcp";
			lifecycle = "eager";
			directTools = true;
		};
	};
}
