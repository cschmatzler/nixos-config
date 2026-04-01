import type { Plugin } from "@opencode-ai/plugin";

export const DirenvPlugin: Plugin = async ({ $ }) => {
	return {
		"shell.env": async (input, output) => {
			try {
				const exported = await $`direnv export json`
					.cwd(input.cwd)
					.quiet()
					.json();

				Object.assign(output.env, exported);
			} catch (error) {
				console.warn("[direnv] failed to export env:", error);
			}
		},
	};
};
