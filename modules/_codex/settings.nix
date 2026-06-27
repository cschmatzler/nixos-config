{
	homeDirectory,
	mcp,
	...
}: let
	trustedProjectPaths = [
		"${homeDirectory}/Projects/Personal/leuchtturm"
		"${homeDirectory}/Projects/Work/tuist"
		"${homeDirectory}/nixos-config"
		"${homeDirectory}/Projects/Personal/shnosh"
		"${homeDirectory}/Projects/Personal"
		"${homeDirectory}/Projects/Personal/roasted"
		"${homeDirectory}/Projects/Personal/chevrotain"
		"${homeDirectory}/Projects/Personal/reverie"
		"${homeDirectory}/Projects/Personal/alchemy-render"
	];
in {
	model = "gpt-5.5";
	model_reasoning_effort = "xhigh";
	personality = "pragmatic";

	projects =
		builtins.listToAttrs
		(map (path: {
					name = path;
					value.trust_level = "trusted";
				})
			trustedProjectPaths);

	features = {
		terminal_resize_reflow = true;
		remote_connections = true;
		goals = true;
		codex_hooks = true;
	};

	mcp_servers = mcp;
}
