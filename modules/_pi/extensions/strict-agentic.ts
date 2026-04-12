import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const STATE_TYPE = "strict-agentic-state";
const RETRY_MESSAGE_TYPE = "strict-agentic-retry";
const BLOCKED_MESSAGE_TYPE = "strict-agentic-blocked";
const MAX_PLANNING_ONLY_RETRIES = 2;
const MAX_PLANNING_ONLY_TEXT_LENGTH = 700;

const BASE_STEERING_INSTRUCTIONS = `## Strict agentic execution

When the user wants repository investigation or code changes, do not stop after describing a plan if you can already act with the available tools.
Prefer concrete action over narration.
Take the first concrete tool action you can.
Only stop without acting when the user explicitly asked only for a plan/explanation, or when a real blocker prevents action.
If blocked, state the exact blocker briefly instead of giving another plan.`;

const PLANNING_ONLY_RETRY_INSTRUCTION =
	"The previous assistant turn only described the plan. Do not restate the plan. Act now: take the first concrete tool action you can. If a real blocker prevents action, reply with the exact blocker in one sentence.";

const ACK_EXECUTION_FAST_PATH_INSTRUCTION =
	"The latest user message is a short approval to proceed. Do not recap or restate the plan. Start with the first concrete tool action immediately. Keep any user-facing follow-up brief and natural.";

const STRICT_AGENTIC_BLOCKED_TEXT =
	"Agent stopped after repeated plan-only turns without taking a concrete action. No concrete tool action advanced the task.";

const PLANNING_ONLY_PROMISE_RE =
	/\b(?:i(?:'ll| will)|let me|going to|first[, ]+i(?:'ll| will)|next[, ]+i(?:'ll| will)|i can do that)\b/i;
const PLANNING_ONLY_COMPLETION_OR_BLOCKER_RE =
	/\b(?:done|finished|implemented|updated|fixed|changed|ran|verified|found|here(?:'s| is) what|blocked by|the blocker is|cannot|can't|unable to|permission denied|missing|no access|read-only|requires approval)\b/i;
const PLANNING_ONLY_HEADING_RE = /^(?:plan|steps?|next steps?)\s*:/i;
const PLANNING_ONLY_BULLET_RE = /^(?:[-*•]\s+|\d+[.)]\s+)/u;
const PLAN_REQUEST_RE = /\b(?:plan|approach|outline|strategy|steps?)\b/i;

const ACK_EXECUTION_NORMALIZED_SET = new Set([
	"ok",
	"okay",
	"ok do it",
	"okay do it",
	"do it",
	"go ahead",
	"please do",
	"sounds good",
	"sounds good do it",
	"ship it",
	"fix it",
	"make it so",
	"yes do it",
	"yep do it",
	"continue",
]);

interface SteeringState {
	retryCount: number;
}

interface BasicMessage {
	role?: string;
	content?: unknown;
	stopReason?: string;
	type?: string;
	message?: {
		role?: string;
		content?: unknown;
		stopReason?: string;
	};
	customType?: string;
}

function isStrictAgenticModel(model: ExtensionContext["model"] | undefined | null): boolean {
	if (!model) {
		return false;
	}

	const provider = model.provider.toLowerCase();
	if (provider !== "openai" && provider !== "openai-codex") {
		return false;
	}

	return /^gpt-5(?:[.-]|$)/i.test(model.id);
}

function normalizePrompt(text: string): string {
	return text
		.normalize("NFKC")
		.trim()
		.replace(/[\p{P}\p{S}]+/gu, " ")
		.replace(/\s+/g, " ")
		.trim()
		.toLowerCase();
}

function isLikelyExecutionAckPrompt(text: string): boolean {
	const trimmed = text.trim();
	if (!trimmed || trimmed.length > 80 || trimmed.includes("\n") || trimmed.includes("?")) {
		return false;
	}

	return ACK_EXECUTION_NORMALIZED_SET.has(normalizePrompt(trimmed));
}

function extractText(content: unknown): string {
	if (typeof content === "string") {
		return content.trim();
	}

	if (!Array.isArray(content)) {
		return "";
	}

	return content
		.filter(
			(part): part is { type: string; text?: string } =>
				typeof part === "object" && part !== null && "type" in part,
		)
		.filter((part) => part.type === "text" && typeof part.text === "string")
		.map((part) => part.text ?? "")
		.join("\n")
		.trim();
}

function getMessage(entry: unknown): BasicMessage | null {
	if (!entry || typeof entry !== "object") {
		return null;
	}

	const candidate = entry as BasicMessage;
	if (candidate.message && typeof candidate.message === "object") {
		return candidate.message;
	}

	return candidate;
}

function getLatestUserText(entries: readonly unknown[]): string | null {
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const message = getMessage(entries[i]);
		if (!message || message.role !== "user") {
			continue;
		}

		const text = extractText(message.content);
		if (text) {
			return text;
		}
	}

	return null;
}

function getLastAssistantMessage(entries: readonly unknown[]): BasicMessage | null {
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const message = getMessage(entries[i]);
		if (message?.role === "assistant") {
			return message;
		}
	}

	return null;
}

function hasToolResults(entries: readonly unknown[]): boolean {
	return entries.some((entry) => getMessage(entry)?.role === "toolResult");
}

function hasStructuredPlanningOnlyFormat(text: string): boolean {
	const lines = text
		.split(/\r?\n/)
		.map((line) => line.trim())
		.filter(Boolean);
	if (lines.length === 0) {
		return false;
	}

	const bulletLineCount = lines.filter((line) => PLANNING_ONLY_BULLET_RE.test(line)).length;
	const hasPlanningCueLine = lines.some((line) => PLANNING_ONLY_PROMISE_RE.test(line));
	const hasPlanningHeading = PLANNING_ONLY_HEADING_RE.test(lines[0] ?? "");

	return (hasPlanningHeading && hasPlanningCueLine) || (bulletLineCount >= 2 && hasPlanningCueLine);
}

function isPlanningOnlyAssistantTurn(params: {
	assistantText: string;
	stopReason?: string;
	userText?: string | null;
	hadToolResults: boolean;
}): boolean {
	if (params.hadToolResults) {
		return false;
	}

	if (params.stopReason && params.stopReason !== "stop") {
		return false;
	}

	if (params.userText && PLAN_REQUEST_RE.test(params.userText)) {
		return false;
	}

	const text = params.assistantText.trim();
	if (!text || text.length > MAX_PLANNING_ONLY_TEXT_LENGTH || text.includes("```")) {
		return false;
	}

	if (text.includes("?")) {
		return false;
	}

	if (PLANNING_ONLY_COMPLETION_OR_BLOCKER_RE.test(text)) {
		return false;
	}

	return PLANNING_ONLY_PROMISE_RE.test(text) || hasStructuredPlanningOnlyFormat(text);
}

function getPersistedState(ctx: ExtensionContext): SteeringState {
	const entries = ctx.sessionManager.getEntries();
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i] as { type?: string; customType?: string; data?: SteeringState };
		if (entry.type === "custom" && entry.customType === STATE_TYPE && entry.data) {
			return {
				retryCount: Math.max(0, Math.trunc(entry.data.retryCount ?? 0)),
			};
		}
	}

	return { retryCount: 0 };
}

function persistState(pi: ExtensionAPI, state: SteeringState): void {
	pi.appendEntry(STATE_TYPE, { retryCount: state.retryCount });
}

export default function strictAgenticExtension(pi: ExtensionAPI) {
	let state: SteeringState = { retryCount: 0 };

	function resetRetries(): void {
		if (state.retryCount === 0) {
			return;
		}

		state = { retryCount: 0 };
		persistState(pi, state);
	}

	function setRetryCount(retryCount: number): void {
		if (state.retryCount === retryCount) {
			return;
		}

		state = { retryCount };
		persistState(pi, state);
	}

	pi.on("session_start", async (_event, ctx) => {
		state = getPersistedState(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		state = getPersistedState(ctx);
	});

	pi.on("input", async (event) => {
		if (event.source !== "extension") {
			resetRetries();
		}
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (!isStrictAgenticModel(ctx.model)) {
			return;
		}

		const latestUserText =
			typeof event.prompt === "string" && event.prompt.trim().length > 0
				? event.prompt
				: getLatestUserText(ctx.sessionManager.getEntries());
		const promptAdditions = [BASE_STEERING_INSTRUCTIONS];
		if (latestUserText && isLikelyExecutionAckPrompt(latestUserText)) {
			promptAdditions.push(ACK_EXECUTION_FAST_PATH_INSTRUCTION);
		}

		return {
			systemPrompt: `${event.systemPrompt}\n\n${promptAdditions.join("\n\n")}`,
		};
	});

	pi.on("agent_end", async (event, ctx) => {
		if (!isStrictAgenticModel(ctx.model)) {
			resetRetries();
			return;
		}

		const messages = Array.isArray(event.messages) ? event.messages : [];
		const lastAssistant = getLastAssistantMessage(messages);
		if (!lastAssistant) {
			resetRetries();
			return;
		}

		const assistantText = extractText(lastAssistant.content);
		const latestUserText = getLatestUserText(messages) ?? getLatestUserText(ctx.sessionManager.getEntries());
		const planningOnly = isPlanningOnlyAssistantTurn({
			assistantText,
			stopReason: lastAssistant.stopReason,
			userText: latestUserText,
			hadToolResults: hasToolResults(messages),
		});

		if (!planningOnly) {
			resetRetries();
			return;
		}

		if (state.retryCount < MAX_PLANNING_ONLY_RETRIES) {
			const nextRetryCount = state.retryCount + 1;
			setRetryCount(nextRetryCount);
			ctx.ui.notify(
				`Strict-agentic steering retry ${nextRetryCount}/${MAX_PLANNING_ONLY_RETRIES}`,
				"info",
			);
			pi.sendMessage(
				{
					customType: RETRY_MESSAGE_TYPE,
					content: PLANNING_ONLY_RETRY_INSTRUCTION,
					display: false,
				},
				{
					deliverAs: "followUp",
					triggerTurn: true,
				},
			);
			return;
		}

		resetRetries();
		ctx.ui.notify(STRICT_AGENTIC_BLOCKED_TEXT, "warning");
		pi.sendMessage(
			{
				customType: BLOCKED_MESSAGE_TYPE,
				content: STRICT_AGENTIC_BLOCKED_TEXT,
				display: true,
			},
			{
				deliverAs: "followUp",
				triggerTurn: false,
			},
		);
	});
}
