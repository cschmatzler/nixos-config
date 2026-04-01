import type { Plugin } from "@opencode-ai/plugin";

const SCRIPTING_PATTERN =
	/(?:^|[;&|]\s*|&&\s*|\|\|\s*|\$\(\s*|`\s*)(?:python[23]?|perl|ruby|php|lua|node\s+-e|bash\s+-c|sh\s+-c)\s/;

export const BlockScriptingPlugin: Plugin = async () => {
	return {
		"tool.execute.before": async (input, output) => {
			if (input.tool === "bash") {
				const command = output.args.command as string;
				if (SCRIPTING_PATTERN.test(command)) {
					throw new Error(
						"Do not use python, perl, ruby, php, lua, or inline bash/sh for scripting. Use `nu -c` instead.",
					);
				}
			}
		},
	};
};
