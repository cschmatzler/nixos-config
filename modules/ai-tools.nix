{inputs, ...}: {
	den.aspects.ai-tools.homeManager = {
		pkgs,
		inputs',
		...
	}: {
		home.packages = [
			inputs'.llm-agents.packages.claude-code
			inputs'.llm-agents.packages.pi
			inputs'.llm-agents.packages.codex
			pkgs.cog-cli
		];

		home.file = {
			".pi/agent/extensions/pi-elixir" = {
				source = inputs.pi-elixir;
				recursive = true;
			};
			".pi/agent/extensions/pi-mcp-adapter" = {
				source = "${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter";
				recursive = true;
			};
			".pi/agent/skills/elixir-dev" = {
				source = "${inputs.pi-elixir}/skills/elixir-dev";
				recursive = true;
			};
			".pi/agent/themes" = {
				source = "${inputs.pi-rose-pine}/themes";
				recursive = true;
			};
			".pi/agent/extensions/no-git.ts".text = ''
				/**
				 * No Git Extension
				 *
				 * Blocks git commands and tells the LLM to use jj (Jujutsu) instead.
				 */

				import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
				import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

				export default function (pi: ExtensionAPI) {
					pi.on("tool_call", async (event, _ctx) => {
						if (!isToolCallEventType("bash", event)) return;

						const command = event.input.command.trim();

						if (/\bgit\b/.test(command) && !/\bjj\s+git\b/.test(command)) {
							return {
								block: true,
								reason: "git is not used in this project. Use jj (Jujutsu) instead.",
							};
						}
					});
				}
			'';
			".pi/agent/extensions/no-scripting.ts".text = ''
				/**
				 * No Scripting Extension
				 *
				 * Blocks python, perl, ruby, php, lua, and inline bash/sh scripts.
				 * Tells the LLM to use `nu -c` instead.
				 */

				import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
				import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

				const SCRIPTING_PATTERN =
					/(?:^|[;&|]\s*|&&\s*|\|\|\s*|\$\(\s*|`\s*)(?:python[23]?|perl|ruby|php|lua|bash\s+-c|sh\s+-c)\s/;

				export default function (pi: ExtensionAPI) {
					pi.on("tool_call", async (event, _ctx) => {
						if (!isToolCallEventType("bash", event)) return;

						const command = event.input.command.trim();

						if (SCRIPTING_PATTERN.test(command)) {
							return {
								block: true,
								reason:
									"Do not use python, perl, ruby, php, lua, or inline bash/sh for scripting. Use `nu -c` instead.",
							};
						}
					});
				}
			'';
			".pi/agent/settings.json".text =
				builtins.toJSON {
					lastChangelogVersion = "0.61.1";
					theme = "rose-pine-dawn";
					hideThinkingBlock = true;
					defaultProvider = "anthropic";
					defaultModel = "claude-opus-4-6";
					defaultThinkingLevel = "high";
					packages = [
						{
							source = "${pkgs.pi-agent-stuff}/lib/node_modules/mitsupi";
							extensions = [
								"pi-extensions/answer.ts"
								"pi-extensions/context.ts"
								"pi-extensions/multi-edit.ts"
								"pi-extensions/review.ts"
								"pi-extensions/todos.ts"
							];
							skills = [];
							prompts = [];
							themes = [];
						}
					];
				};
			".pi/agent/mcp.json".text =
				builtins.toJSON {
					mcpServers = {
						opensrc = {
							command = "npx";
							args = ["-y" "opensrc-mcp"];
						};
						context7 = {
							url = "https://mcp.context7.com/mcp";
						};
						grep_app = {
							url = "https://mcp.grep.app";
						};
						sentry = {
							url = "https://mcp.sentry.dev/mcp";
							auth = "oauth";
						};
					};
				};
		};
	};
}
