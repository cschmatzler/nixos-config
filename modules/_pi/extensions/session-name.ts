import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import {
	createAgentSession,
	DefaultResourceLoader,
	getAgentDir,
	SessionManager,
	SettingsManager,
} from "@mariozechner/pi-coding-agent";

interface SessionNameState {
	hasAutoNamed: boolean;
}

const TITLE_MODEL = {
	provider: "openai-codex",
	id: "gpt-5.4-mini",
} as const;

const MAX_TITLE_LENGTH = 50;
const MAX_RETRIES = 2;
const FALLBACK_LENGTH = 50;
const TITLE_ENTRY_TYPE = "vendored-session-title";

const TITLE_SYSTEM_PROMPT = `You are generating a succinct title for a coding session based on the provided conversation.

Requirements:
- Maximum 50 characters
- Sentence case (capitalize only first word and proper nouns)
- Capture the main intent or task
- Reuse the user's exact words and technical terms
- Match the user's language
- No quotes, colons, or markdown formatting
- No generic titles like "Coding session" or "Help with code"
- No explanations or commentary

Output ONLY the title text. Nothing else.`;

function isTurnCompleted(event: unknown): boolean {
	if (!event || typeof event !== "object") return false;
	const message = (event as { message?: unknown }).message;
	if (!message || typeof message !== "object") return false;
	const stopReason = (message as { stopReason?: unknown }).stopReason;
	return typeof stopReason === "string" && stopReason.toLowerCase() === "stop";
}

function buildFallbackTitle(userText: string): string {
	const text = userText.trim();
	if (text.length <= FALLBACK_LENGTH) return text;
	const truncated = text.slice(0, FALLBACK_LENGTH - 3);
	const lastSpace = truncated.lastIndexOf(" ");
	return `${lastSpace > 0 ? truncated.slice(0, lastSpace) : truncated}...`;
}

function postProcessTitle(raw: string): string {
	let title = raw;

	title = title.replace(/<thinking[\s\S]*?<\/thinking>\s*/g, "");
	title = title.replace(/^["'`]+|["'`]+$/g, "");
	title = title.replace(/^#+\s*/, "");
	title = title.replace(/\*{1,2}(.*?)\*{1,2}/g, "$1");
	title = title.replace(/_{1,2}(.*?)_{1,2}/g, "$1");
	title = title.replace(/^(Title|Summary|Session)\s*:\s*/i, "");
	title =
		title
			.split("\n")
			.map((line) => line.trim())
			.find((line) => line.length > 0) ?? title;
	title = title.trim();

	if (title.length > MAX_TITLE_LENGTH) {
		const truncated = title.slice(0, MAX_TITLE_LENGTH - 3);
		const lastSpace = truncated.lastIndexOf(" ");
		title = `${lastSpace > 0 ? truncated.slice(0, lastSpace) : truncated}...`;
	}

	return title;
}

function getLatestUserText(ctx: ExtensionContext): string | null {
	const entries = ctx.sessionManager.getEntries();
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (!entry || entry.type !== "message") continue;
		if (entry.message.role !== "user") continue;

		const { content } = entry.message as { content: unknown };
		if (typeof content === "string") return content;
		if (!Array.isArray(content)) return null;

		return content
			.filter(
				(part): part is { type: string; text?: string } =>
					typeof part === "object" && part !== null && "type" in part,
			)
			.filter((part) => part.type === "text" && typeof part.text === "string")
			.map((part) => part.text ?? "")
			.join(" ");
	}

	return null;
}

function getLatestAssistantText(ctx: ExtensionContext): string | null {
	const entries = ctx.sessionManager.getEntries();
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (!entry || entry.type !== "message") continue;
		if (entry.message.role !== "assistant") continue;

		const { content } = entry.message as { content: unknown };
		if (typeof content === "string") return content;
		if (!Array.isArray(content)) return null;

		return content
			.filter(
				(part): part is { type: string; text?: string } =>
					typeof part === "object" && part !== null && "type" in part,
			)
			.filter((part) => part.type === "text" && typeof part.text === "string")
			.map((part) => part.text ?? "")
			.join("\n");
	}

	return null;
}

function resolveModel(ctx: ExtensionContext) {
	const available = ctx.modelRegistry.getAvailable();
	const model = available.find(
		(candidate) => candidate.provider === TITLE_MODEL.provider && candidate.id === TITLE_MODEL.id,
	);
	if (model) return model;

	const existsWithoutKey = ctx.modelRegistry
		.getAll()
		.some((candidate) => candidate.provider === TITLE_MODEL.provider && candidate.id === TITLE_MODEL.id);
	if (existsWithoutKey) {
		throw new Error(
			`Model ${TITLE_MODEL.provider}/${TITLE_MODEL.id} exists but has no configured API key.`,
		);
	}

	throw new Error(`Model ${TITLE_MODEL.provider}/${TITLE_MODEL.id} is not available.`);
}

async function generateTitle(userText: string, assistantText: string, ctx: ExtensionContext): Promise<string> {
	const agentDir = getAgentDir();
	const settingsManager = SettingsManager.create(ctx.cwd, agentDir);
	const resourceLoader = new DefaultResourceLoader({
		cwd: ctx.cwd,
		agentDir,
		settingsManager,
		noExtensions: true,
		noPromptTemplates: true,
		noThemes: true,
		noSkills: true,
		systemPromptOverride: () => TITLE_SYSTEM_PROMPT,
		appendSystemPromptOverride: () => [],
		agentsFilesOverride: () => ({ agentsFiles: [] }),
	});
	await resourceLoader.reload();

	const { session } = await createAgentSession({
		model: resolveModel(ctx),
		thinkingLevel: "off",
		sessionManager: SessionManager.inMemory(),
		modelRegistry: ctx.modelRegistry,
		resourceLoader,
	});

	let accumulated = "";
	const unsubscribe = session.subscribe((event) => {
		if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
			accumulated += event.assistantMessageEvent.delta;
		}
	});

	const description = assistantText
		? `<user>${userText}</user>\n<assistant>${assistantText}</assistant>`
		: `<user>${userText}</user>`;
	const userMessage = `<conversation>\n${description}\n</conversation>\n\nGenerate a title:`;

	try {
		await session.prompt(userMessage);
	} finally {
		unsubscribe();
		session.dispose();
	}

	return postProcessTitle(accumulated);
}

async function generateAndSetTitle(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
	const userText = getLatestUserText(ctx);
	if (!userText?.trim()) return;

	const assistantText = getLatestAssistantText(ctx) ?? "";
	if (!assistantText.trim()) return;

	let lastError: Error | null = null;
	for (let attempt = 1; attempt <= MAX_RETRIES; attempt += 1) {
		try {
			const title = await generateTitle(userText, assistantText, ctx);
			if (!title) continue;

			pi.setSessionName(title);
			pi.appendEntry(TITLE_ENTRY_TYPE, {
				title,
				rawUserText: userText,
				rawAssistantText: assistantText,
				attempt,
				model: `${TITLE_MODEL.provider}/${TITLE_MODEL.id}`,
			});
			ctx.ui.notify(`Session: ${title}`, "info");
			return;
		} catch (error) {
			lastError = error instanceof Error ? error : new Error(String(error));
		}
	}

	const fallback = buildFallbackTitle(userText);
	pi.setSessionName(fallback);
	pi.appendEntry(TITLE_ENTRY_TYPE, {
		title: fallback,
		fallback: true,
		error: lastError?.message ?? "Unknown error",
		rawUserText: userText,
		rawAssistantText: assistantText,
		model: `${TITLE_MODEL.provider}/${TITLE_MODEL.id}`,
	});
	ctx.ui.notify(`Title generation failed, using fallback: ${fallback}`, "warning");
}

export default function setupSessionNameHook(pi: ExtensionAPI) {
	const state: SessionNameState = {
		hasAutoNamed: false,
	};

	pi.on("session_start", async () => {
		state.hasAutoNamed = false;
	});

	pi.on("session_switch", async () => {
		state.hasAutoNamed = false;
	});

	pi.on("turn_end", async (event, ctx) => {
		if (state.hasAutoNamed) return;

		if (pi.getSessionName()) {
			state.hasAutoNamed = true;
			return;
		}

		if (!isTurnCompleted(event)) return;

		await generateAndSetTitle(pi, ctx);
		state.hasAutoNamed = true;
	});
}
