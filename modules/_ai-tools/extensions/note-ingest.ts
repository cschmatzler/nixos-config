import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import * as crypto from "node:crypto";
import { Box, Text } from "@mariozechner/pi-tui";
import type { ExtensionAPI, ExtensionContext, ExtensionCommandContext, Model } from "@mariozechner/pi-coding-agent";
import {
	createAgentSession,
	DefaultResourceLoader,
	getAgentDir,
	SessionManager,
	SettingsManager,
} from "@mariozechner/pi-coding-agent";

interface IngestManifest {
	version: number;
	job_id: string;
	note_id: string;
	operation: string;
	requested_at: string;
	title: string;
	source_relpath: string;
	source_path: string;
	input_path: string;
	archive_path: string;
	output_path: string;
	transcript_path: string;
	result_path: string;
	session_dir: string;
	source_hash: string;
	last_generated_output_hash?: string | null;
	force_overwrite_generated?: boolean;
	source_transport?: string;
}

interface IngestResult {
	success: boolean;
	job_id: string;
	note_id: string;
	archive_path: string;
	source_hash: string;
	session_dir: string;
	output_path?: string;
	output_hash?: string;
	conflict_path?: string;
	write_mode?: "create" | "overwrite" | "force-overwrite" | "conflict";
	updated_main_output?: boolean;
	transcript_path?: string;
	error?: string;
}

interface FrontmatterInfo {
	values: Record<string, string>;
	body: string;
}

interface RenderedPage {
	path: string;
	image: {
		type: "image";
		source: {
			type: "base64";
			mediaType: string;
			data: string;
		};
	};
}

const TRANSCRIBE_SKILL = "notability-transcribe";
const NORMALIZE_SKILL = "notability-normalize";
const STATUS_TYPE = "notability-status";
const DEFAULT_TRANSCRIBE_THINKING = "low" as const;
const DEFAULT_NORMALIZE_THINKING = "off" as const;
const PREFERRED_VISION_MODEL: [string, string] = ["openai-codex", "gpt-5.4"];

function getNotesRoot(): string {
	return process.env.NOTABILITY_NOTES_DIR ?? path.join(os.homedir(), "Notes");
}

function getDataRoot(): string {
	return process.env.NOTABILITY_DATA_ROOT ?? path.join(os.homedir(), ".local", "share", "notability-ingest");
}

function getRenderRoot(): string {
	return process.env.NOTABILITY_RENDER_ROOT ?? path.join(getDataRoot(), "rendered-pages");
}

function getNotabilityScriptDir(): string {
	return path.join(getAgentDir(), "notability");
}

function getSkillPath(skillName: string): string {
	return path.join(getAgentDir(), "skills", skillName, "SKILL.md");
}

function stripFrontmatterBlock(text: string): string {
	const trimmed = text.trim();
	if (!trimmed.startsWith("---\n")) return trimmed;
	const end = trimmed.indexOf("\n---\n", 4);
	if (end === -1) return trimmed;
	return trimmed.slice(end + 5).trim();
}

function stripCodeFence(text: string): string {
	const trimmed = text.trim();
	const match = trimmed.match(/^```(?:markdown|md)?\n([\s\S]*?)\n```$/i);
	return match ? match[1].trim() : trimmed;
}

function parseFrontmatter(text: string): FrontmatterInfo {
	const trimmed = stripCodeFence(text);
	if (!trimmed.startsWith("---\n")) {
		return { values: {}, body: trimmed };
	}

	const end = trimmed.indexOf("\n---\n", 4);
	if (end === -1) {
		return { values: {}, body: trimmed };
	}

	const block = trimmed.slice(4, end);
	const body = trimmed.slice(end + 5).trim();
	const values: Record<string, string> = {};
	for (const line of block.split("\n")) {
		const idx = line.indexOf(":");
		if (idx === -1) continue;
		const key = line.slice(0, idx).trim();
		const value = line.slice(idx + 1).trim();
		values[key] = value;
	}
	return { values, body };
}

function quoteYaml(value: string): string {
	return JSON.stringify(value);
}

function sha256(content: string | Buffer): string {
	return crypto.createHash("sha256").update(content).digest("hex");
}

async function sha256File(filePath: string): Promise<string> {
	const buffer = await readFile(filePath);
	return sha256(buffer);
}

function extractTitle(normalized: string, fallbackTitle: string): string {
	const parsed = parseFrontmatter(normalized);
	const frontmatterTitle = parsed.values.title?.replace(/^['"]|['"]$/g, "").trim();
	if (frontmatterTitle) return frontmatterTitle;
	const heading = parsed.body
		.split("\n")
		.map((line) => line.trim())
		.find((line) => line.startsWith("# "));
	if (heading) return heading.replace(/^#\s+/, "").trim();
	return fallbackTitle;
}

function sourceFormat(filePath: string): string {
	const extension = path.extname(filePath).toLowerCase();
	if (extension === ".pdf") return "pdf";
	if (extension === ".png") return "png";
	return extension.replace(/^\./, "") || "unknown";
}

function buildMarkdown(manifest: IngestManifest, normalized: string): string {
	const parsed = parseFrontmatter(normalized);
	const title = extractTitle(normalized, manifest.title);
	const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
	const created = manifest.requested_at.slice(0, 10);
	const body = parsed.body.trim();
	const outputBody = body.length > 0 ? body : `# ${title}\n`;

	return [
		"---",
		`title: ${quoteYaml(title)}`,
		`created: ${quoteYaml(created)}`,
		`updated: ${quoteYaml(now.slice(0, 10))}`,
		`source: ${quoteYaml("notability")}`,
		`source_transport: ${quoteYaml(manifest.source_transport ?? "webdav")}`,
		`source_relpath: ${quoteYaml(manifest.source_relpath)}`,
		`note_id: ${quoteYaml(manifest.note_id)}`,
		`managed_by: ${quoteYaml("notability-ingest")}`,
		`source_file: ${quoteYaml(manifest.archive_path)}`,
		`source_file_hash: ${quoteYaml(`sha256:${manifest.source_hash}`)}`,
		`source_format: ${quoteYaml(sourceFormat(manifest.archive_path))}`,
		`status: ${quoteYaml("active")}`,
		"tags:",
		"  - handwritten",
		"  - notability",
		"---",
		"",
		outputBody,
		"",
	].join("\n");
}

function conflictPathFor(outputPath: string): string {
	const parsed = path.parse(outputPath);
	const stamp = new Date().toISOString().replace(/[:]/g, "-").replace(/\.\d{3}Z$/, "Z");
	return path.join(parsed.dir, `${parsed.name}.conflict-${stamp}${parsed.ext}`);
}

async function ensureParent(filePath: string): Promise<void> {
	await mkdir(path.dirname(filePath), { recursive: true });
}

async function loadSkillText(skillName: string): Promise<string> {
	const raw = await readFile(getSkillPath(skillName), "utf8");
	return stripFrontmatterBlock(raw).trim();
}

function normalizePathArg(arg: string): string {
	return arg.startsWith("@") ? arg.slice(1) : arg;
}

function resolveModel(ctx: ExtensionContext, requireImage = false): Model {
	const available = ctx.modelRegistry.getAvailable();
	const matching = requireImage ? available.filter((model) => model.input.includes("image")) : available;

	if (matching.length === 0) {
		throw new Error(
			requireImage
				? "No image-capable model configured for pi note ingestion"
				: "No available model configured for pi note ingestion",
		);
	}

	if (ctx.model && (!requireImage || ctx.model.input.includes("image"))) {
		if (!requireImage) return ctx.model;
	}

	if (requireImage) {
		const [provider, id] = PREFERRED_VISION_MODEL;
		const preferred = matching.find((model) => model.provider === provider && model.id === id);
		if (preferred) return preferred;

		const subscriptionModel = matching.find(
			(model) => model.provider !== "opencode" && model.provider !== "opencode-go",
		);
		if (subscriptionModel) return subscriptionModel;
	}

	if (ctx.model && (!requireImage || ctx.model.input.includes("image"))) {
		return ctx.model;
	}

	return matching[0];
}

async function runSkillPrompt(
	ctx: ExtensionContext,
	systemPrompt: string,
	prompt: string,
	images: RenderedPage[] = [],
	thinkingLevel: "off" | "low" = "off",
): Promise<string> {
	if (images.length > 0) {
		const model = resolveModel(ctx, true);
		const { execFile } = await import("node:child_process");
		const promptPath = path.join(os.tmpdir(), `pi-note-ingest-${crypto.randomUUID()}.md`);
		await writeFile(promptPath, `${prompt}\n`);
		const args = [
			"45s",
			"pi",
			"--model",
			`${model.provider}/${model.id}`,
			"--thinking",
			thinkingLevel,
			"--no-tools",
			"--no-session",
			"-p",
			...images.map((page) => `@${page.path}`),
			`@${promptPath}`,
		];

		try {
			const output = await new Promise<string>((resolve, reject) => {
				execFile("timeout", args, { cwd: ctx.cwd, env: process.env, maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
					if ((stdout ?? "").trim().length > 0) {
						resolve(stdout);
						return;
					}
					if (error) {
						reject(new Error(stderr || stdout || error.message));
						return;
					}
					resolve(stdout);
				});
			});

			return stripCodeFence(output).trim();
		} finally {
			try {
				fs.unlinkSync(promptPath);
			} catch {
				// Ignore temp file cleanup failures.
			}
		}
	}

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
		systemPromptOverride: () => systemPrompt,
		appendSystemPromptOverride: () => [],
		agentsFilesOverride: () => ({ agentsFiles: [] }),
	});
	await resourceLoader.reload();

	const { session } = await createAgentSession({
		model: resolveModel(ctx, images.length > 0),
		thinkingLevel,
		sessionManager: SessionManager.inMemory(),
		modelRegistry: ctx.modelRegistry,
		resourceLoader,
		tools: [],
	});

	let output = "";
	const unsubscribe = session.subscribe((event) => {
		if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
			output += event.assistantMessageEvent.delta;
		}
	});

	try {
		await session.prompt(prompt, {
			images: images.map((page) => page.image),
		});
	} finally {
		unsubscribe();
	}

	if (!output.trim()) {
		const assistantMessages = session.messages.filter((message) => message.role === "assistant");
		const lastAssistant = assistantMessages.at(-1);
		if (lastAssistant && Array.isArray(lastAssistant.content)) {
			output = lastAssistant.content
				.filter((part) => part.type === "text")
				.map((part) => part.text)
				.join("");
		}
	}

	session.dispose();
	return stripCodeFence(output).trim();
}

async function renderPdfPages(pdfPath: string, jobId: string): Promise<RenderedPage[]> {
	const renderDir = path.join(getRenderRoot(), jobId);
	await mkdir(renderDir, { recursive: true });
	const prefix = path.join(renderDir, "page");
	const args = ["-png", "-r", "200", pdfPath, prefix];
	const { execFile } = await import("node:child_process");
	await new Promise<void>((resolve, reject) => {
		execFile("pdftoppm", args, (error) => {
			if (error) reject(error);
			else resolve();
		});
	});

	const entries = await readdir(renderDir);
	const pngs = entries
		.filter((entry) => entry.endsWith(".png"))
		.sort((left, right) => left.localeCompare(right, undefined, { numeric: true }));
	if (pngs.length === 0) {
		throw new Error(`No rendered pages produced for ${pdfPath}`);
	}

	const pages: RenderedPage[] = [];
	for (const entry of pngs) {
		const pagePath = path.join(renderDir, entry);
		const buffer = await readFile(pagePath);
		pages.push({
			path: pagePath,
			image: {
				type: "image",
				source: {
					type: "base64",
					mediaType: "image/png",
					data: buffer.toString("base64"),
				},
			},
		});
	}
	return pages;
}

async function loadImagePage(imagePath: string): Promise<RenderedPage> {
	const extension = path.extname(imagePath).toLowerCase();
	const mediaType = extension === ".png" ? "image/png" : undefined;
	if (!mediaType) {
		throw new Error(`Unsupported image input format for ${imagePath}`);
	}

	const buffer = await readFile(imagePath);
	return {
		path: imagePath,
		image: {
			type: "image",
			source: {
				type: "base64",
				mediaType,
				data: buffer.toString("base64"),
			},
		},
	};
}

async function renderInputPages(inputPath: string, jobId: string): Promise<RenderedPage[]> {
	const extension = path.extname(inputPath).toLowerCase();
	if (extension === ".pdf") {
		return await renderPdfPages(inputPath, jobId);
	}
	if (extension === ".png") {
		return [await loadImagePage(inputPath)];
	}
	throw new Error(`Unsupported Notability input format: ${inputPath}`);
}

async function findManagedOutputs(noteId: string): Promise<string[]> {
	const matches: string[] = [];
	const stack = [getNotesRoot()];

	while (stack.length > 0) {
		const currentDir = stack.pop();
		if (!currentDir || !fs.existsSync(currentDir)) continue;

		const entries = await readdir(currentDir, { withFileTypes: true });
		for (const entry of entries) {
			if (entry.name.startsWith(".")) continue;
			const fullPath = path.join(currentDir, entry.name);
			if (entry.isDirectory()) {
				stack.push(fullPath);
				continue;
			}
			if (!entry.isFile() || !entry.name.endsWith(".md")) continue;

			try {
				const parsed = parseFrontmatter(await readFile(fullPath, "utf8"));
				const managedBy = parsed.values.managed_by?.replace(/^['"]|['"]$/g, "");
				const frontmatterNoteId = parsed.values.note_id?.replace(/^['"]|['"]$/g, "");
				if (managedBy === "notability-ingest" && frontmatterNoteId === noteId) {
					matches.push(fullPath);
				}
			} catch {
				// Ignore unreadable or malformed files while scanning the notebook.
			}
		}
	}

	return matches.sort();
}

async function resolveManagedOutputPath(noteId: string, configuredOutputPath: string): Promise<string> {
	if (fs.existsSync(configuredOutputPath)) {
		const parsed = parseFrontmatter(await readFile(configuredOutputPath, "utf8"));
		const managedBy = parsed.values.managed_by?.replace(/^['"]|['"]$/g, "");
		const frontmatterNoteId = parsed.values.note_id?.replace(/^['"]|['"]$/g, "");
		if (managedBy === "notability-ingest" && frontmatterNoteId === noteId) {
			return configuredOutputPath;
		}
	}

	const discovered = await findManagedOutputs(noteId);
	if (discovered.length === 0) return configuredOutputPath;
	if (discovered.length === 1) return discovered[0];

	throw new Error(
		`Multiple managed note files found for ${noteId}: ${discovered.join(", ")}`,
	);
}

async function determineWriteTarget(manifest: IngestManifest, markdown: string): Promise<{
	outputPath: string;
	writePath: string;
	writeMode: "create" | "overwrite" | "force-overwrite" | "conflict";
	updatedMainOutput: boolean;
}> {
	const outputPath = await resolveManagedOutputPath(manifest.note_id, manifest.output_path);
	if (!fs.existsSync(outputPath)) {
		return { outputPath, writePath: outputPath, writeMode: "create", updatedMainOutput: true };
	}

	const existing = await readFile(outputPath, "utf8");
	const existingHash = sha256(existing);
	const parsed = parseFrontmatter(existing);
	const isManaged = parsed.values.managed_by?.replace(/^['"]|['"]$/g, "") === "notability-ingest";
	const sameNoteId = parsed.values.note_id?.replace(/^['"]|['"]$/g, "") === manifest.note_id;

	if (manifest.last_generated_output_hash && existingHash === manifest.last_generated_output_hash) {
		return { outputPath, writePath: outputPath, writeMode: "overwrite", updatedMainOutput: true };
	}

	if (manifest.force_overwrite_generated && isManaged && sameNoteId) {
		return { outputPath, writePath: outputPath, writeMode: "force-overwrite", updatedMainOutput: true };
	}

	return {
		outputPath,
		writePath: conflictPathFor(outputPath),
		writeMode: "conflict",
		updatedMainOutput: false,
	};
}

async function writeIngestResult(resultPath: string, payload: IngestResult): Promise<void> {
	await ensureParent(resultPath);
	await writeFile(resultPath, JSON.stringify(payload, null, 2));
}

async function ingestManifest(manifestPath: string, ctx: ExtensionContext): Promise<IngestResult> {
	const manifest = JSON.parse(await readFile(manifestPath, "utf8")) as IngestManifest;
	await ensureParent(manifest.transcript_path);
	await ensureParent(manifest.result_path);
	await mkdir(manifest.session_dir, { recursive: true });

	const normalizeSkill = await loadSkillText(NORMALIZE_SKILL);
	const pages = await renderInputPages(manifest.input_path, manifest.job_id);
	const pageSummary = pages.map((page, index) => `- page ${index + 1}: ${page.path}`).join("\n");
	const transcriptPrompt = [
		"Transcribe this note into clean Markdown.",
		"Read it like a human and preserve the intended reading order and visible structure.",
		"Keep headings, lists, and paragraphs when they are visible.",
		"Do not summarize. Do not add commentary. Return Markdown only.",
		"Rendered pages:",
		pageSummary,
	].join("\n\n");
	let transcript = await runSkillPrompt(
		ctx,
		"",
		transcriptPrompt,
		pages,
		DEFAULT_TRANSCRIBE_THINKING,
	);
	if (!transcript.trim()) {
		throw new Error("Transcription skill returned empty output");
	}
	await writeFile(manifest.transcript_path, `${transcript.trim()}\n`);

	const normalizePrompt = [
		`Note ID: ${manifest.note_id}`,
		`Source path: ${manifest.source_relpath}`,
		`Preferred output path: ${manifest.output_path}`,
		"Normalize the following transcription into clean Markdown.",
		"Restore natural prose formatting and intended reading order when the transcription contains OCR or layout artifacts.",
		"If words are split across separate lines but clearly belong to the same phrase or sentence, merge them.",
		"Return only Markdown. No code fences.",
		"",
		"<transcription>",
		transcript.trim(),
		"</transcription>",
	].join("\n");
	const normalized = await runSkillPrompt(
		ctx,
		normalizeSkill,
		normalizePrompt,
		[],
		DEFAULT_NORMALIZE_THINKING,
	);
	if (!normalized.trim()) {
		throw new Error("Normalization skill returned empty output");
	}

	const markdown = buildMarkdown(manifest, normalized);
	const target = await determineWriteTarget(manifest, markdown);
	await ensureParent(target.writePath);
	await writeFile(target.writePath, markdown);

	const result: IngestResult = {
		success: true,
		job_id: manifest.job_id,
		note_id: manifest.note_id,
		archive_path: manifest.archive_path,
		source_hash: manifest.source_hash,
		session_dir: manifest.session_dir,
		output_path: target.outputPath,
		output_hash: target.updatedMainOutput ? await sha256File(target.writePath) : undefined,
		conflict_path: target.writeMode === "conflict" ? target.writePath : undefined,
		write_mode: target.writeMode,
		updated_main_output: target.updatedMainOutput,
		transcript_path: manifest.transcript_path,
	};
	await writeIngestResult(manifest.result_path, result);
	return result;
}

async function runScript(scriptName: string, args: string[]): Promise<string> {
	const { execFile } = await import("node:child_process");
	const scriptPath = path.join(getNotabilityScriptDir(), scriptName);
	return await new Promise<string>((resolve, reject) => {
		execFile("nu", [scriptPath, ...args], (error, stdout, stderr) => {
			if (error) {
				reject(new Error(stderr || stdout || error.message));
				return;
			}
			resolve(stdout.trim());
		});
	});
}

function splitArgs(input: string): string[] {
	return input
		.trim()
		.split(/\s+/)
		.filter((part) => part.length > 0);
}

function postStatus(pi: ExtensionAPI, content: string): void {
	pi.sendMessage({
		customType: STATUS_TYPE,
		content,
		display: true,
	});
}

export default function noteIngestExtension(pi: ExtensionAPI) {
	pi.registerMessageRenderer(STATUS_TYPE, (message, _options, theme) => {
		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		box.addChild(new Text(message.content, 0, 0));
		return box;
	});

	pi.registerCommand("note-status", {
		description: "Show Notability ingest status",
		handler: async (args, _ctx) => {
			const output = await runScript("status.nu", splitArgs(args));
			postStatus(pi, output.length > 0 ? output : "No status output");
		},
	});

	pi.registerCommand("note-reingest", {
		description: "Enqueue a note for reingestion",
		handler: async (args, _ctx) => {
			const trimmed = args.trim();
			if (!trimmed) {
				postStatus(pi, "Usage: /note-reingest <note-id> [--latest-source|--latest-archive] [--force-overwrite-generated]");
				return;
			}
			const output = await runScript("reingest.nu", splitArgs(trimmed));
			postStatus(pi, output.length > 0 ? output : "Reingest enqueued");
		},
	});

	pi.registerCommand("note-ingest", {
		description: "Ingest a queued Notability job manifest",
		handler: async (args, ctx: ExtensionCommandContext) => {
			const manifestPath = normalizePathArg(args.trim());
			if (!manifestPath) {
				throw new Error("Usage: /note-ingest <job.json>");
			}

			let resultPath = "";
			try {
				const raw = await readFile(manifestPath, "utf8");
				const manifest = JSON.parse(raw) as IngestManifest;
				resultPath = manifest.result_path;
				const result = await ingestManifest(manifestPath, ctx);
				postStatus(pi, `Ingested ${result.note_id} (${result.write_mode})`);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				if (resultPath) {
					const manifest = JSON.parse(await readFile(manifestPath, "utf8")) as IngestManifest;
					await writeIngestResult(resultPath, {
						success: false,
						job_id: manifest.job_id,
						note_id: manifest.note_id,
						archive_path: manifest.archive_path,
						source_hash: manifest.source_hash,
						session_dir: manifest.session_dir,
						error: message,
					});
				}
				throw error;
			}
		},
	});
}
