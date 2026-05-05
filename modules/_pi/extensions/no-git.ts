/**
 * No Git Extension
 *
 * Blocks direct git invocations and tells the LLM to use jj (Jujutsu) instead.
 * Mentions of the word "git" in search patterns, strings, comments, etc. are allowed.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

type ShellToken =
	| { type: "word"; value: string }
	| { type: "operator"; value: string };

const COMMAND_PREFIXES = new Set(["env", "command", "builtin", "time", "sudo", "nohup", "nice"]);
const SHELL_KEYWORDS = new Set(["if", "then", "elif", "else", "do", "while", "until", "case", "in"]);
const SHELL_INTERPRETERS = new Set(["bash", "sh", "zsh", "fish"]);

function isAssignmentWord(value: string): boolean {
	return /^[A-Za-z_][A-Za-z0-9_]*=.*/.test(value);
}

function tokenizeShell(command: string): ShellToken[] {
	const tokens: ShellToken[] = [];
	let current = "";
	let quote: "'" | '"' | null = null;

	const pushWord = () => {
		if (!current) return;
		tokens.push({ type: "word", value: current });
		current = "";
	};

	for (let i = 0; i < command.length; i++) {
		const char = command[i];

		if (quote) {
			if (quote === "'") {
				if (char === "'") {
					quote = null;
				} else {
					current += char;
				}
				continue;
			}

			if (char === '"') {
				quote = null;
				continue;
			}

			if (char === "\\") {
				if (i + 1 < command.length) {
					current += command[i + 1];
					i += 1;
				}
				continue;
			}

			current += char;
			continue;
		}

		if (char === "'" || char === '"') {
			quote = char;
			continue;
		}

		if (char === "\\") {
			if (i + 1 < command.length) {
				current += command[i + 1];
				i += 1;
			}
			continue;
		}

		if (/\s/.test(char)) {
			pushWord();
			if (char === "\n") {
				tokens.push({ type: "operator", value: "\n" });
			}
			continue;
		}

		const twoCharOperator = command.slice(i, i + 2);
		if (twoCharOperator === "&&" || twoCharOperator === "||") {
			pushWord();
			tokens.push({ type: "operator", value: twoCharOperator });
			i += 1;
			continue;
		}

		if (char === ";" || char === "|" || char === "(" || char === ")") {
			pushWord();
			tokens.push({ type: "operator", value: char });
			continue;
		}

		current += char;
	}

	pushWord();
	return tokens;
}

function findCommandWord(words: string[]): { word?: string; index: number } {
	for (let i = 0; i < words.length; i++) {
		const word = words[i];
		if (SHELL_KEYWORDS.has(word)) {
			continue;
		}
		if (isAssignmentWord(word)) {
			continue;
		}
		if (COMMAND_PREFIXES.has(word)) {
			continue;
		}

		return { word, index: i };
	}

	return { index: words.length };
}

function getInlineShellCommand(words: string[], commandIndex: number): string | null {
	for (let i = commandIndex + 1; i < words.length; i++) {
		const word = words[i];
		if (/^(?:-[A-Za-z]*c[A-Za-z]*|--command)$/.test(word)) {
			return words[i + 1] ?? null;
		}
	}

	return null;
}

function segmentContainsBlockedGit(words: string[]): boolean {
	const { word, index } = findCommandWord(words);
	if (!word) {
		return false;
	}

	if (word === "git") {
		return true;
	}

	if (word === "jj") {
		return false;
	}

	if (SHELL_INTERPRETERS.has(word)) {
		const inlineCommand = getInlineShellCommand(words, index);
		return inlineCommand ? containsBlockedGitInvocation(inlineCommand) : false;
	}

	return false;
}

function containsBlockedGitInvocation(command: string): boolean {
	const tokens = tokenizeShell(command);
	let words: string[] = [];

	for (const token of tokens) {
		if (token.type === "operator") {
			if (segmentContainsBlockedGit(words)) {
				return true;
			}
			words = [];
			continue;
		}

		words.push(token.value);
	}

	return segmentContainsBlockedGit(words);
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, _ctx) => {
		if (!isToolCallEventType("bash", event)) return;

		const command = event.input.command.trim();

		if (containsBlockedGitInvocation(command)) {
			return {
				block: true,
				reason: "git is not used in this project. Use jj (Jujutsu) instead.",
			};
		}
	});
}
