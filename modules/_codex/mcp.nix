{...}: {
	executor = {
		enabled = true;
		url = "https://executor.sh/leuchtturm/mcp?elicitation_mode=browser";
	};

	opensrc = {
		command = "npx";
		args = [
			"-y"
			"opensrc-mcp"
		];
		enabled = true;
		tools.execute.approval_mode = "approve";
	};
}
