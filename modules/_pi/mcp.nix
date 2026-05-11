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
		context7 = {
			url = "https://mcp.context7.com/mcp";
			directTools = true;
			lifecycle = "eager";
			auth = "oauth";
		};
		ynab = {
			command = "uv";
			args = [
				"tool"
				"run"
				"mcp-ynab"
			];
			lifecycle = "eager";
			env.LD_LIBRARY_PATH =
				lib.makeLibraryPath [
					pkgs.stdenv.cc.cc.lib
				];
		};
	};
}
