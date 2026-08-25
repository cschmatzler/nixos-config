import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, truncateTail } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

type AgentStatus = "idle" | "working" | "blocked" | "done" | "unknown";
type ReadSource = "visible" | "recent" | "recent-unwrapped" | "detection";
type SplitDirection = "right" | "down";
type OutputFormat = "text" | "ansi";

interface TabInfo {
	tab_id: string;
	workspace_id: string;
	label: string;
	focused: boolean;
	agent_status: AgentStatus;
}

interface PaneInfo {
	pane_id: string;
	workspace_id: string;
	tab_id: string;
	focused: boolean;
	cwd?: string;
	foreground_cwd?: string;
	label?: string;
	agent?: string;
	agent_status: AgentStatus;
}

interface AgentInfo {
	name?: string;
	agent?: string;
	display_agent?: string;
	agent_status: AgentStatus;
	workspace_id: string;
	tab_id: string;
	pane_id: string;
	focused: boolean;
	cwd?: string;
}

interface PaneLayoutRect {
	x: number;
	y: number;
	width: number;
	height: number;
}

interface PaneLayoutSnapshot {
	workspace_id: string;
	tab_id: string;
	zoomed: boolean;
	focused_pane_id: string;
	area: PaneLayoutRect;
	panes: Array<{ pane_id: string; focused: boolean; rect: PaneLayoutRect }>;
	splits: Array<{ id: string; direction: SplitDirection; ratio: number; rect: PaneLayoutRect }>;
}

interface HerdrJsonEnvelope {
	result?: unknown;
	error?: {
		code?: string;
		message?: string;
	};
}

const StatusEnum = StringEnum(["idle", "working", "blocked", "done", "unknown"] as const, {
	description: "Agent lifecycle state",
});

const ReadSourceEnum = StringEnum(["visible", "recent", "recent-unwrapped", "detection"] as const, {
	description: "Terminal snapshot source",
});

const OutputFormatEnum = StringEnum(["text", "ansi"] as const, {
	description: "Output format; ansi preserves terminal styling",
});

const DirectionEnum = StringEnum(["right", "down"] as const, {
	description: "Split direction. When omitted, the tool chooses from the source pane geometry.",
});

const AutomationShellEnvironment = "HERDR_SKIP_DEVENV_AUTOACTIVATE=1";
const HelperExcludedTools = ["herdr_layout", "herdr_pane", "herdr_agent"] as const;
const SubagentTabLabel = "subagents";
const SubagentMetadataToken = "subagent=↳ subagent";
const AllowedLayoutActions = new Set(["tab_list", "tab_create", "pane_list", "pane_split"]);

const AgentKindEnum = StringEnum(
	[
		"pi",
		"claude",
		"codex",
		"gemini",
		"cursor",
		"devin",
		"agy",
		"cline",
		"omp",
		"mastracode",
		"opencode",
		"copilot",
		"kimi",
		"kiro",
		"droid",
		"amp",
		"grok",
		"hermes",
		"kilo",
		"qodercli",
		"qwen",
		"maki",
	] as const,
	{ description: "Supported coding agent kind and canonical executable" },
);

function piHelperAgentArgs(agentArgs: readonly string[]): string[] {
	const excludedTools = new Set<string>(HelperExcludedTools);
	const retainedArgs: string[] = [];

	for (let index = 0; index < agentArgs.length; index++) {
		const argument = agentArgs[index];
		if (argument !== "--exclude-tools" && argument !== "-xt") {
			retainedArgs.push(argument);
			continue;
		}

		const value = agentArgs[index + 1];
		if (value === undefined || value.startsWith("-") || value.startsWith("@")) continue;
		for (const tool of value.split(",").map((name) => name.trim()).filter(Boolean)) excludedTools.add(tool);
		index++;
	}

	return ["--exclude-tools", [...excludedTools].join(","), ...retainedArgs];
}

function parseHerdrError(output: string): string | null {
	const trimmed = output.trim();
	if (!trimmed) return null;
	try {
		const value = JSON.parse(trimmed) as HerdrJsonEnvelope;
		return value.error?.message || value.error?.code || trimmed;
	} catch {
		return trimmed;
	}
}

function isAbortError(error: unknown, signal?: AbortSignal): boolean {
	return signal?.aborted === true || (error instanceof Error && error.message === "Aborted");
}

function formatOutput(output: string): string {
	const truncation = truncateTail(output, {
		maxLines: DEFAULT_MAX_LINES,
		maxBytes: DEFAULT_MAX_BYTES,
	});
	if (!truncation.truncated) return truncation.content;
	return `[Showing last ${truncation.outputLines} of ${truncation.totalLines} lines]\n${truncation.content}`;
}

function chooseSplitDirection(layout: PaneLayoutSnapshot, paneId: string): SplitDirection {
	const pane = layout.panes.find((candidate) => candidate.pane_id === paneId);
	if (!pane) return "right";
	return pane.rect.width >= 80 && pane.rect.width >= pane.rect.height * 2 ? "right" : "down";
}

function statusDot(theme: any, status: AgentStatus): string {
	switch (status) {
		case "blocked":
			return theme.fg("warning", "●");
		case "working":
			return theme.fg("accent", "●");
		case "done":
			return theme.fg("success", "●");
		case "idle":
			return theme.fg("muted", "○");
		default:
			return theme.fg("dim", "·");
	}
}

function agentDisplayName(agent: AgentInfo): string {
	return agent.name || agent.display_agent || agent.agent || agent.pane_id;
}

function summarizeAgent(agent: AgentInfo): string {
	const cwd = agent.cwd ? ` ${agent.cwd}` : "";
	return `${agentDisplayName(agent)}: [${agent.pane_id}] (${agent.agent_status}${agent.focused ? ", focused" : ""})${cwd}`;
}

function summarizePane(pane: PaneInfo, currentPaneId?: string): string {
	const flags = [
		pane.pane_id === currentPaneId ? "current" : pane.focused ? "focused" : null,
		pane.agent,
		pane.agent_status !== "unknown" ? pane.agent_status : null,
	]
		.filter(Boolean)
		.join(", ");
	const cwd = pane.foreground_cwd || pane.cwd;
	return `${pane.label || pane.pane_id}: [${pane.pane_id}]${flags ? ` (${flags})` : ""}${cwd ? ` ${cwd}` : ""}`;
}

function summarizeTab(tab: TabInfo): string {
	const flags = [tab.focused ? "focused" : null, tab.agent_status !== "unknown" ? tab.agent_status : null]
		.filter(Boolean)
		.join(", ");
	return `${tab.label}: [${tab.tab_id}]${flags ? ` (${flags})` : ""}`;
}

function renderToolCall(tool: string, args: Record<string, any>, theme: any, context: any) {
	const component = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
	let text = theme.fg("toolTitle", theme.bold(`${tool} `));
	text += theme.fg("accent", args.action || "?");
	const target = args.target || args.pane || args.tab || args.workspace;
	if (target) text += theme.fg("muted", ` ${target}`);
	if (args.name) text += theme.fg("muted", ` ${args.name}`);
	if (args.kind) text += theme.fg("dim", ` › ${args.kind}`);
	if (args.direction) text += theme.fg("dim", ` › ${args.direction}`);
	if (args.command) text += theme.fg("dim", ` › ${args.command}`);
	if (args.prompt) text += theme.fg("dim", ` › ${args.prompt}`);
	if (args.match) text += theme.fg("dim", ` › ${args.match}`);
	component.setText(text);
	return component;
}

function renderToolResult(result: any, options: { expanded: boolean; isPartial: boolean }, theme: any) {
	if (options.isPartial) return new Text(theme.fg("warning", "◌ waiting"), 0, 0);
	const details = result.details as Record<string, any> | undefined;
	const content = result.content?.[0];
	const rawText = content?.type === "text" ? content.text : "";
	if (!details) return new Text(rawText, 0, 0);

	if (details.agent) {
		const agent = details.agent as AgentInfo;
		return new Text(
			`${statusDot(theme, agent.agent_status)} ${theme.fg("accent", agentDisplayName(agent))} ${theme.fg("dim", agent.agent_status)}`,
			0,
			0,
		);
	}
	if (Array.isArray(details.agents)) {
		const agents = details.agents as AgentInfo[];
		return new Text(
			agents.length
				? agents
					.map(
						(agent) =>
							`${statusDot(theme, agent.agent_status)} ${theme.fg(agent.focused ? "accent" : "muted", agentDisplayName(agent))} ${theme.fg("dim", agent.agent_status)}`,
					)
					.join("\n")
				: theme.fg("dim", "no agents"),
			0,
			0,
		);
	}
	if (details.read) {
		let text = theme.fg("accent", `▤ ${details.target || details.pane}`);
		if (options.expanded && rawText) text += `\n${rawText.split("\n").slice(0, 40).map((line: string) => theme.fg("dim", line)).join("\n")}`;
		return new Text(text, 0, 0);
	}
	return new Text(theme.fg("success", `✓ ${details.action || "done"}`), 0, 0);
}

export default function (pi: ExtensionAPI) {
	if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_PANE_ID) return;

	async function execHerdr(args: string[], signal?: AbortSignal) {
		const result = await pi.exec("herdr", args, { signal });
		if (signal?.aborted || result.killed) throw new Error("Aborted");
		if (result.code !== 0) {
			const message =
				parseHerdrError(result.stderr) ||
				parseHerdrError(result.stdout) ||
				`herdr ${args.join(" ")} failed with exit code ${result.code}`;
			throw new Error(message);
		}
		return result;
	}

	async function execHerdrJson<T>(args: string[], signal?: AbortSignal): Promise<T> {
		const result = await execHerdr(args, signal);
		const stdout = result.stdout.trim();
		if (!stdout) throw new Error(`Expected JSON output from herdr ${args.join(" ")}`);
		let value: HerdrJsonEnvelope;
		try {
			value = JSON.parse(stdout) as HerdrJsonEnvelope;
		} catch {
			throw new Error(`Failed to parse JSON from herdr ${args.join(" ")}`);
		}
		if (value.error) throw new Error(value.error.message || value.error.code || `herdr ${args.join(" ")} failed`);
		return value as T;
	}

	async function execHerdrText(args: string[], signal?: AbortSignal): Promise<string> {
		return (await execHerdr(args, signal)).stdout;
	}

	async function getCurrentPane(signal?: AbortSignal): Promise<PaneInfo> {
		const response = await execHerdrJson<{ result: { pane: PaneInfo } }>(["pane", "current", "--current"], signal);
		return response.result.pane;
	}

	async function getPane(paneId: string, signal?: AbortSignal): Promise<PaneInfo> {
		const response = await execHerdrJson<{ result: { pane: PaneInfo } }>(["pane", "get", paneId], signal);
		return response.result.pane;
	}

	async function getTabs(workspaceId: string, signal?: AbortSignal): Promise<TabInfo[]> {
		const response = await execHerdrJson<{ result: { tabs: TabInfo[] } }>(
			["tab", "list", "--workspace", workspaceId],
			signal,
		);
		return response.result.tabs || [];
	}

	async function requireSubagentPane(pane: PaneInfo, signal?: AbortSignal): Promise<void> {
		const current = await getCurrentPane(signal);
		if (pane.workspace_id !== current.workspace_id) {
			throw new Error(`Herdr is restricted to subagents in the current workspace; pane ${pane.pane_id} is elsewhere.`);
		}
		const tabs = await getTabs(current.workspace_id, signal);
		const tab = tabs.find((candidate) => candidate.tab_id === pane.tab_id);
		if (tab?.label !== SubagentTabLabel) {
			throw new Error(`Herdr is restricted to subagents; pane ${pane.pane_id} is not in the ${SubagentTabLabel} tab.`);
		}
	}

	async function getSubagent(target: string, signal?: AbortSignal): Promise<AgentInfo> {
		const response = await execHerdrJson<{ result: { agent: AgentInfo } }>(["agent", "get", target], signal);
		const agent = response.result.agent;
		await requireSubagentPane(await getPane(agent.pane_id, signal), signal);
		return agent;
	}

	async function getPaneLayout(paneId: string, signal?: AbortSignal): Promise<PaneLayoutSnapshot> {
		const response = await execHerdrJson<{ result: { layout: PaneLayoutSnapshot } }>(
			["pane", "layout", "--pane", paneId],
			signal,
		);
		return response.result.layout;
	}

	pi.registerTool({
		name: "herdr_layout",
		label: "Herdr Layout",
		description:
			"Create and inspect only the background topology needed to host coding subagents. Herdr must never be used for shell commands, tests, builds, deployments, servers, logs, search, file printing, or any other ordinary process. Only tab_list, tab_create, pane_list, and pane_split are permitted; created and split panes are confined to the current workspace's subagents tab.",
		promptSnippet: "Create subagent panes only; never run ordinary processes through Herdr",
		promptGuidelines: [
			"Use Herdr exclusively to spawn and control coding subagents. Never use it for commands, tests, builds, deployments, servers, logs, grep/search, file printing, or any non-agent process.",
			"Use herdr_layout only to create or find the background tab named subagents and panes inside it, then use herdr_agent to start the helper.",
			"Keep the caller's tab unsplit and preserve UI focus.",
			"Read opaque tab and pane IDs from tool results instead of constructing them.",
		],
		parameters: Type.Object({
			action: StringEnum(["tab_list", "tab_create", "pane_list", "pane_split"] as const, {
				description: "Subagent layout action",
			}),
			pane: Type.Optional(Type.String({ description: "Opaque source pane ID in the subagents tab; required for pane_split" })),
			direction: Type.Optional(DirectionEnum),
		}),
		async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
			if (!AllowedLayoutActions.has(params.action)) {
				throw new Error(`Herdr is restricted to subagents; layout action ${params.action} is not allowed.`);
			}
			switch (params.action) {
				case "tab_list": {
					const current = await getCurrentPane(signal);
					const tabs = (await getTabs(current.workspace_id, signal)).filter((tab) => tab.label === SubagentTabLabel);
					return {
						content: [{ type: "text", text: tabs.length ? tabs.map(summarizeTab).join("\n") : "No tabs." }],
						details: { action: "tab_list", tabs },
					};
				}
				case "tab_create": {
					const current = await getCurrentPane(signal);
					const args = ["tab", "create", "--workspace", current.workspace_id];
					args.push("--cwd", current.foreground_cwd || current.cwd || process.cwd());
					args.push("--env", AutomationShellEnvironment, "--label", SubagentTabLabel, "--no-focus");
					const response = await execHerdrJson<{ result: { tab: TabInfo; root_pane: PaneInfo } }>(args, signal);
					const { tab, root_pane: rootPane } = response.result;
					return {
						content: [{ type: "text", text: `Created tab ${tab.tab_id}, root pane ${rootPane.pane_id}` }],
						details: { action: "tab_create", tab, pane: rootPane },
					};
				}
				case "pane_list": {
					const current = await getCurrentPane(signal);
					const workspaceId = current.workspace_id;
					const subagentTabIds = new Set(
						(await getTabs(workspaceId, signal))
							.filter((tab) => tab.label === SubagentTabLabel)
							.map((tab) => tab.tab_id),
					);
					const response = await execHerdrJson<{ result: { panes: PaneInfo[] } }>(
						["pane", "list", "--workspace", workspaceId],
						signal,
					);
					const panes = (response.result.panes || []).filter((pane) => subagentTabIds.has(pane.tab_id));
					return {
						content: [{ type: "text", text: panes.length ? panes.map((pane) => summarizePane(pane, current.pane_id)).join("\n") : "No panes." }],
						details: { action: "pane_list", panes, workspaceId },
					};
				}
				case "pane_split": {
					if (!params.pane) throw new Error("'pane' is required for pane_split");
					const source = await getPane(params.pane, signal);
					await requireSubagentPane(source, signal);
					const direction = params.direction || chooseSplitDirection(await getPaneLayout(source.pane_id, signal), source.pane_id);
					const cwd = source.foreground_cwd || source.cwd || process.cwd();
					const args = ["pane", "split", source.pane_id, "--direction", direction, "--cwd", cwd];
					args.push("--env", AutomationShellEnvironment, "--no-focus");
					const response = await execHerdrJson<{ result: { pane: PaneInfo } }>(args, signal);
					const pane = response.result.pane;
					return {
						content: [{ type: "text", text: `Created pane ${pane.pane_id} by splitting ${source.pane_id} ${direction}` }],
						details: { action: "pane_split", pane, sourcePaneId: source.pane_id, direction },
					};
				}
			}
		},
		renderCall(args, theme, context) {
			return renderToolCall("herdr_layout", args, theme, context);
		},
		renderResult(result, options, theme) {
			return renderToolResult(result, options, theme);
		},
	});

	pi.registerTool({
		name: "herdr_agent",
		label: "Herdr Agent",
		description:
			"Spawn and control coding subagents in panes from the current workspace's subagents tab. This tool cannot control agents elsewhere, and Herdr provides no raw pane or command tool. Never use Herdr for shell commands, tests, builds, deployments, servers, logs, grep/search, file printing, or any non-agent process. Lifecycle states are working, blocked, done, idle, and unknown; prompt and wait default to the first settled idle, done, or blocked state.",
		promptSnippet: "Spawn and control coding subagents only",
		promptGuidelines: [
			"Use Herdr exclusively to spawn and control coding subagents. Do not use it as a terminal, process runner, deployment mechanism, search tool, or file viewer.",
			"Create or reuse the current workspace's background subagents tab with herdr_layout, then start the helper with herdr_agent.",
			"Start helpers with kind pi unless the user explicitly requests another coding-agent kind. Pi helpers cannot use Herdr, preventing recursive delegation.",
			"Use prompt, wait, read, and send_keys only to interact with a recognized subagent in the subagents tab.",
			"Treat idle and done as ready, blocked as requiring inspection or input, and unknown as uncertain rather than completed.",
		],
		parameters: Type.Object({
			action: StringEnum(["list", "get", "start", "prompt", "wait", "read", "send_keys"] as const, {
				description: "Agent lifecycle action",
			}),
			target: Type.Optional(Type.String({ description: "Unique live agent name or pane ID currently hosting the agent" })),
			pane: Type.Optional(Type.String({ description: "Existing available shell pane ID for start" })),
			name: Type.Optional(
				Type.String({
					pattern: "^[a-z][a-z0-9_-]{0,31}$",
					description: "Unique subagent name for start",
				}),
			),
			kind: Type.Optional(AgentKindEnum),
			agentArgs: Type.Optional(
				Type.Array(Type.String(), {
					description: "Native agent arguments passed after -- for start. Pi helpers start with Herdr tools excluded.",
				}),
			),
			prompt: Type.Optional(Type.String({ description: "Prompt text submitted atomically with Enter" })),
			wait: Type.Optional(Type.Boolean({ description: "Wait for lifecycle settlement after prompt. Defaults to true." })),
			until: Type.Optional(Type.Array(StatusEnum, { description: "Accepted lifecycle states for prompt with wait or wait; defaults to idle, done, or blocked" })),
			timeout: Type.Optional(Type.Integer({ minimum: 1, description: "Timeout in milliseconds; omitted means indefinite" })),
			source: Type.Optional(ReadSourceEnum),
			lines: Type.Optional(Type.Integer({ minimum: 1, description: "Rendered terminal rows to read" })),
			format: Type.Optional(OutputFormatEnum),
			keys: Type.Optional(Type.Array(Type.String(), { description: "Logical UI keys such as esc, enter, up, or ctrl+c" })),
		}),
		async execute(_toolCallId, params, signal, onUpdate, _ctx) {
			switch (params.action) {
				case "list": {
					const current = await getCurrentPane(signal);
					const subagentTabIds = new Set(
						(await getTabs(current.workspace_id, signal))
							.filter((tab) => tab.label === SubagentTabLabel)
							.map((tab) => tab.tab_id),
					);
					const response = await execHerdrJson<{ result: { agents: AgentInfo[] } }>(["agent", "list"], signal);
					const agents = (response.result.agents || []).filter(
						(agent) => agent.workspace_id === current.workspace_id && subagentTabIds.has(agent.tab_id),
					);
					return {
						content: [{ type: "text", text: agents.length ? agents.map(summarizeAgent).join("\n") : "No agents." }],
						details: { action: "list", agents },
					};
				}
				case "get": {
					if (!params.target) throw new Error("'target' is required for get");
					const agent = await getSubagent(params.target, signal);
					return {
						content: [{ type: "text", text: summarizeAgent(agent) }],
						details: { action: "get", agent },
					};
				}
				case "start": {
					if (!params.name) throw new Error("'name' is required for start");
					if (!params.pane) throw new Error("'pane' is required for start");
					if (params.timeout != null && (params.timeout <= 3000 || params.timeout > 300000)) {
						throw new Error("start timeout must be greater than 3000ms and at most 300000ms");
					}
					const pane = await getPane(params.pane, signal);
					await requireSubagentPane(pane, signal);
					const kind = params.kind ?? "pi";
					await execHerdr(
						["pane", "report-metadata", params.pane, "--source", "pi-herdr", "--token", SubagentMetadataToken],
						signal,
					);
					const args = ["agent", "start", params.name, "--kind", kind, "--pane", params.pane];
					if (params.timeout != null) args.push("--timeout", String(params.timeout));
					const nativeArgs = kind === "pi" ? piHelperAgentArgs(params.agentArgs ?? []) : (params.agentArgs ?? []);
					if (nativeArgs.length) args.push("--", ...nativeArgs);
					onUpdate?.({
						content: [{ type: "text", text: `Starting ${kind} as ${params.name} in ${params.pane}...` }],
						details: { action: "start", waiting: true },
					});
					const response = await execHerdrJson<{ result: { agent: AgentInfo } }>(args, signal);
					return {
						content: [{ type: "text", text: `Started ${summarizeAgent(response.result.agent)}` }],
						details: { action: "start", agent: response.result.agent },
					};
				}
				case "prompt": {
					if (!params.target) throw new Error("'target' is required for prompt");
					if (!params.prompt) throw new Error("'prompt' is required for prompt");
					await getSubagent(params.target, signal);
					const shouldWait = params.wait !== false;
					if (!shouldWait && params.until?.length) throw new Error("'until' requires wait for prompt");
					if (!shouldWait && params.timeout != null) throw new Error("'timeout' requires wait for prompt");
					const args = ["agent", "prompt", params.target, params.prompt];
					if (shouldWait) args.push("--wait");
					for (const status of params.until || []) args.push("--until", status);
					if (params.timeout != null) args.push("--timeout", String(params.timeout));
					if (shouldWait) {
						onUpdate?.({
							content: [{ type: "text", text: `Prompted ${params.target}; waiting for lifecycle settlement...` }],
							details: { action: "prompt", target: params.target, waiting: true },
						});
					}
					const response = await execHerdrJson<{ result: { agent: AgentInfo } }>(args, signal);
					return {
						content: [{ type: "text", text: `${shouldWait ? "Prompt settled" : "Prompt submitted"}: ${summarizeAgent(response.result.agent)}` }],
						details: { action: "prompt", agent: response.result.agent },
					};
				}
				case "wait": {
					if (!params.target) throw new Error("'target' is required for wait");
					await getSubagent(params.target, signal);
					const args = ["agent", "wait", params.target];
					for (const status of params.until || []) args.push("--until", status);
					if (params.timeout != null) args.push("--timeout", String(params.timeout));
					onUpdate?.({
						content: [{ type: "text", text: `Waiting for agent ${params.target}...` }],
						details: { action: "wait", target: params.target, waiting: true },
					});
					const response = await execHerdrJson<{ result: { agent: AgentInfo } }>(args, signal);
					return {
						content: [{ type: "text", text: `Agent settled: ${summarizeAgent(response.result.agent)}` }],
						details: { action: "wait", agent: response.result.agent },
					};
				}
				case "read": {
					if (!params.target) throw new Error("'target' is required for read");
					await getSubagent(params.target, signal);
					const args = ["agent", "read", params.target, "--source", params.source || "recent-unwrapped"];
					if (params.lines != null) args.push("--lines", String(params.lines));
					if (params.format) args.push("--format", params.format as OutputFormat);
					const output = await execHerdrText(args, signal);
					return {
						content: [{ type: "text", text: formatOutput(output) }],
						details: { action: "read", target: params.target, read: true, source: params.source || "recent-unwrapped" },
					};
				}
				case "send_keys": {
					if (!params.target) throw new Error("'target' is required for send_keys");
					if (!params.keys?.length) throw new Error("'keys' is required for send_keys");
					await getSubagent(params.target, signal);
					await execHerdrJson(["agent", "send-keys", params.target, ...params.keys], signal);
					return {
						content: [{ type: "text", text: `Sent ${params.keys.join(" ")} to ${params.target}` }],
						details: { action: "send_keys", target: params.target, keys: params.keys },
					};
				}
			}
		},
		renderCall(args, theme, context) {
			return renderToolCall("herdr_agent", args, theme, context);
		},
		renderResult(result, options, theme) {
			return renderToolResult(result, options, theme);
		},
	});
}
