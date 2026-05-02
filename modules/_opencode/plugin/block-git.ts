import type { Plugin } from "@opencode-ai/plugin";

const COMMAND_PREFIXES = new Set([
	"env",
	"command",
	"builtin",
	"time",
	"sudo",
	"nohup",
	"nice",
]);

function findCommandWord(words: string[]): string | undefined {
	for (const word of words) {
		if (COMMAND_PREFIXES.has(word)) continue;
		if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(word)) continue;
		return word;
	}
	return undefined;
}

function segmentHasGit(words: string[]): boolean {
	const cmd = findCommandWord(words);
	return cmd === "git";
}

function containsBlockedGit(command: string): boolean {
	const segments = command.split(/\s*(?:&&|\|\||[;&|]|\$\(|`)\s*/);
	for (const segment of segments) {
		const words = segment.trim().split(/\s+/).filter(Boolean);
		if (segmentHasGit(words)) return true;
	}
	return false;
}

export const BlockGitPlugin: Plugin = async () => {
	return {
		"tool.execute.before": async (input, output) => {
			if (input.tool === "bash") {
				const command = output.args.command as string;
				if (containsBlockedGit(command)) {
					throw new Error(
						"This project uses jj, only use `jj` commands, not `git`.",
					);
				}
			}
		},
	};
};
