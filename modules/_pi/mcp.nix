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
			lifecycle = "eager";
		};
		sentry = {
			url = "https://mcp.sentry.dev/mcp";
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
