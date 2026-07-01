{...}: {
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
		url = "https://executor.sh/leuchtturm/mcp";
		enabled = true;
	};
}
