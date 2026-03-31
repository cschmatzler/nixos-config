import type { Plugin } from "@opencode-ai/plugin";

const GIT_PATTERN = /(?:^|[;&|]\s*|&&\s*|\|\|\s*|\$\(\s*|`\s*)git\s/;

export const BlockGitPlugin: Plugin = async () => {
	return {
		"tool.execute.before": async (input, output) => {
			if (input.tool === "bash") {
				const command = output.args.command as string;
				if (GIT_PATTERN.test(command)) {
					throw new Error(
						"This project uses jj, only use `jj` commands, not `git`.",
					);
				}
			}
		},
	};
};
