/**
 * Code Review Extension (inspired by Codex's review feature)
 *
 * Provides a `/review` command that prompts the agent to review code changes.
 * Supports multiple review modes:
 * - Review a GitHub pull request (materializes the PR locally with jj)
 * - Review against a base bookmark (PR style)
 * - Review working-copy changes
 * - Review a specific change
 * - Shared custom review instructions (applied to all review modes when configured)
 *
 * Usage:
 * - `/review` - show interactive selector
 * - `/review pr 123` - review PR #123 (materializes it locally with jj)
 * - `/review pr https://github.com/owner/repo/pull/123` - review PR from URL
 * - `/review working-copy` - review working-copy changes directly
 * - `/review bookmark main` - review against the main bookmark
 * - `/review change abc123` - review a specific change
 * - `/review folder src docs` - review specific folders/files (snapshot, not diff)
 * - `/review` selector includes Add/Remove custom review instructions (applies to all modes)
 * - `/review --extra "focus on performance regressions"` - add extra review instruction (works with any mode)
 *
 * Project-specific review guidelines:
 * - If a REVIEW_GUIDELINES.md file exists in the same directory as .pi,
 *   its contents are appended to the review prompt.
 *
 * Note: PR review requires a clean working copy (no local jj changes).
 */

import type { ExtensionAPI, ExtensionContext, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { DynamicBorder, BorderedLoader } from "@mariozechner/pi-coding-agent";
import {
	Container,
	fuzzyFilter,
	Input,
	type SelectItem,
	SelectList,
	Spacer,
	Text,
} from "@mariozechner/pi-tui";
import path from "node:path";
import { promises as fs } from "node:fs";

// State to track fresh session review (where we branched from).
// Module-level state means only one review can be active at a time.
// This is intentional - the UI and /end-review command assume a single active review.
let reviewOriginId: string | undefined = undefined;
let endReviewInProgress = false;
let reviewLoopFixingEnabled = false;
let reviewCustomInstructions: string | undefined = undefined;
let reviewLoopInProgress = false;

const REVIEW_STATE_TYPE = "review-session";
const REVIEW_ANCHOR_TYPE = "review-anchor";
const REVIEW_SETTINGS_TYPE = "review-settings";
const REVIEW_LOOP_MAX_ITERATIONS = 10;
const REVIEW_LOOP_START_TIMEOUT_MS = 15000;
const REVIEW_LOOP_START_POLL_MS = 50;

type ReviewSessionState = {
	active: boolean;
	originId?: string;
};

type ReviewSettingsState = {
	loopFixingEnabled?: boolean;
	customInstructions?: string;
};

function setReviewWidget(ctx: ExtensionContext, active: boolean) {
	if (!ctx.hasUI) return;
	if (!active) {
		ctx.ui.setWidget("review", undefined);
		return;
	}

	ctx.ui.setWidget("review", (_tui, theme) => {
		const message = reviewLoopInProgress
			? "Review session active (loop fixing running)"
			: reviewLoopFixingEnabled
				? "Review session active (loop fixing enabled), return with /end-review"
				: "Review session active, return with /end-review";
		const text = new Text(theme.fg("warning", message), 0, 0);
		return {
			render(width: number) {
				return text.render(width);
			},
			invalidate() {
				text.invalidate();
			},
		};
	});
}

function getReviewState(ctx: ExtensionContext): ReviewSessionState | undefined {
	let state: ReviewSessionState | undefined;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type === "custom" && entry.customType === REVIEW_STATE_TYPE) {
			state = entry.data as ReviewSessionState | undefined;
		}
	}

	return state;
}

function applyReviewState(ctx: ExtensionContext) {
	const state = getReviewState(ctx);

	if (state?.active && state.originId) {
		reviewOriginId = state.originId;
		setReviewWidget(ctx, true);
		return;
	}

	reviewOriginId = undefined;
	setReviewWidget(ctx, false);
}

function getReviewSettings(ctx: ExtensionContext): ReviewSettingsState {
	let state: ReviewSettingsState | undefined;
	for (const entry of ctx.sessionManager.getEntries()) {
		if (entry.type === "custom" && entry.customType === REVIEW_SETTINGS_TYPE) {
			state = entry.data as ReviewSettingsState | undefined;
		}
	}

	return {
		loopFixingEnabled: state?.loopFixingEnabled === true,
		customInstructions: state?.customInstructions?.trim() || undefined,
	};
}

function applyReviewSettings(ctx: ExtensionContext) {
	const state = getReviewSettings(ctx);
	reviewLoopFixingEnabled = state.loopFixingEnabled === true;
	reviewCustomInstructions = state.customInstructions?.trim() || undefined;
}

function parseMarkdownHeading(line: string): { level: number; title: string } | null {
	const headingMatch = line.match(/^\s*(#{1,6})\s+(.+?)\s*$/);
	if (!headingMatch) {
		return null;
	}

	const rawTitle = headingMatch[2].replace(/\s+#+\s*$/, "").trim();
	return {
		level: headingMatch[1].length,
		title: rawTitle,
	};
}

function getFindingsSectionBounds(lines: string[]): { start: number; end: number } | null {
	let start = -1;
	let findingsHeadingLevel: number | null = null;

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const heading = parseMarkdownHeading(line);
		if (heading && /^findings\b/i.test(heading.title)) {
			start = i + 1;
			findingsHeadingLevel = heading.level;
			break;
		}
		if (/^\s*findings\s*:?\s*$/i.test(line)) {
			start = i + 1;
			break;
		}
	}

	if (start < 0) {
		return null;
	}

	let end = lines.length;
	for (let i = start; i < lines.length; i++) {
		const line = lines[i];
		const heading = parseMarkdownHeading(line);
		if (heading) {
			const normalizedTitle = heading.title.replace(/[*_`]/g, "").trim();
			if (/^(review scope|verdict|overall verdict|fix queue|constraints(?:\s*&\s*preferences)?)\b:?/i.test(normalizedTitle)) {
				end = i;
				break;
			}

			if (/\[P[0-3]\]/i.test(heading.title)) {
				continue;
			}

			if (findingsHeadingLevel !== null && heading.level <= findingsHeadingLevel) {
				end = i;
				break;
			}
		}

		if (/^\s*(review scope|verdict|overall verdict|fix queue|constraints(?:\s*&\s*preferences)?)\b:?/i.test(line)) {
			end = i;
			break;
		}
	}

	return { start, end };
}

function isLikelyFindingLine(line: string): boolean {
	if (!/\[P[0-3]\]/i.test(line)) {
		return false;
	}

	if (/^\s*(?:[-*+]|(?:\d+)[.)]|#{1,6})\s+priority\s+tag\b/i.test(line)) {
		return false;
	}

	if (/^\s*(?:[-*+]|(?:\d+)[.)]|#{1,6})\s+\[P[0-3]\]\s*-\s*(?:drop everything|urgent|normal|low|nice to have)\b/i.test(line)) {
		return false;
	}

	const allPriorityTags = line.match(/\[P[0-3]\]/gi) ?? [];
	if (allPriorityTags.length > 1) {
		return false;
	}

	if (/^\s*(?:[-*+]|(?:\d+)[.)])\s+/.test(line)) {
		return true;
	}

	if (/^\s*#{1,6}\s+/.test(line)) {
		return true;
	}

	if (/^\s*(?:\*\*|__)?\[P[0-3]\](?:\*\*|__)?(?=\s|:|-)/i.test(line)) {
		return true;
	}

	return false;
}

function normalizeVerdictValue(value: string): string {
	return value
		.trim()
		.replace(/^[-*+]\s*/, "")
		.replace(/^['"`]+|['"`]+$/g, "")
		.toLowerCase();
}

function isNeedsAttentionVerdictValue(value: string): boolean {
	const normalized = normalizeVerdictValue(value);
	if (!normalized.includes("needs attention")) {
		return false;
	}

	if (/\bnot\s+needs\s+attention\b/.test(normalized)) {
		return false;
	}

	// Reject rubric/choice phrasing like "correct or needs attention", but
	// keep legitimate verdict text that may contain unrelated "or".
	if (/\bcorrect\b/.test(normalized) && /\bor\b/.test(normalized)) {
		return false;
	}

	return true;
}

function hasNeedsAttentionVerdict(messageText: string): boolean {
	const lines = messageText.split(/\r?\n/);

	for (const line of lines) {
		const inlineMatch = line.match(/^\s*(?:[*-+]\s*)?(?:overall\s+)?verdict\s*:\s*(.+)$/i);
		if (inlineMatch && isNeedsAttentionVerdictValue(inlineMatch[1])) {
			return true;
		}
	}

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const heading = parseMarkdownHeading(line);

		let verdictLevel: number | null = null;
		if (heading) {
			const normalizedHeading = heading.title.replace(/[*_`]/g, "").trim();
			if (!/^(?:overall\s+)?verdict\b/i.test(normalizedHeading)) {
				continue;
			}
			verdictLevel = heading.level;
		} else if (!/^\s*(?:overall\s+)?verdict\s*:?\s*$/i.test(line)) {
			continue;
		}

		for (let j = i + 1; j < lines.length; j++) {
			const verdictLine = lines[j];
			const nextHeading = parseMarkdownHeading(verdictLine);
			if (nextHeading) {
				const normalizedNextHeading = nextHeading.title.replace(/[*_`]/g, "").trim();
				if (verdictLevel === null || nextHeading.level <= verdictLevel) {
					break;
				}
				if (/^(review scope|findings|fix queue|constraints(?:\s*&\s*preferences)?)\b:?/i.test(normalizedNextHeading)) {
					break;
				}
			}

			const trimmed = verdictLine.trim();
			if (!trimmed) {
				continue;
			}

			if (isNeedsAttentionVerdictValue(trimmed)) {
				return true;
			}

			if (/\bcorrect\b/i.test(normalizeVerdictValue(trimmed))) {
				break;
			}
		}
	}

	return false;
}

function hasBlockingReviewFindings(messageText: string): boolean {
	const lines = messageText.split(/\r?\n/);
	const bounds = getFindingsSectionBounds(lines);
	const candidateLines = bounds ? lines.slice(bounds.start, bounds.end) : lines;

	let inCodeFence = false;
	let foundTaggedFinding = false;
	for (const line of candidateLines) {
		if (/^\s*```/.test(line)) {
			inCodeFence = !inCodeFence;
			continue;
		}
		if (inCodeFence) {
			continue;
		}

		if (!isLikelyFindingLine(line)) {
			continue;
		}

		foundTaggedFinding = true;
		if (/\[(P0|P1|P2)\]/i.test(line)) {
			return true;
		}
	}

	if (foundTaggedFinding) {
		return false;
	}

	return hasNeedsAttentionVerdict(messageText);
}

// Review target types (matching Codex's approach)
type BookmarkRef = {
	name: string;
	remote?: string;
};

type ReviewTarget =
	| { type: "workingCopy" }
	| { type: "baseBookmark"; bookmark: string; remote?: string }
	| { type: "change"; sha: string; title?: string }
	| { type: "pullRequest"; prNumber: number; baseBookmark: string; baseRemote?: string; title: string }
	| { type: "folder"; paths: string[] };

// Prompts (adapted from Codex)
const WORKING_COPY_PROMPT =
	"Review the current working-copy changes (including new files) and provide prioritized findings.";

const LOCAL_CHANGES_REVIEW_INSTRUCTIONS =
	"Also include local working-copy changes (including new files) on top of this bookmark. Use `jj status`, `jj diff --summary`, and `jj diff` so local fixes are part of this review cycle.";

const BASE_BOOKMARK_PROMPT_WITH_MERGE_BASE =
	"Review the code changes against the base bookmark '{baseBookmark}'. The merge-base revision for this comparison is {mergeBaseSha}. Run `jj diff --from {mergeBaseSha} --to @` to inspect the changes relative to {baseBookmark}. Provide prioritized, actionable findings.";

const BASE_BOOKMARK_PROMPT_FALLBACK =
	"Review the code changes against the base bookmark '{bookmark}'. Start by finding the merge-base revision between the working copy and {bookmark}, then run `jj diff --from <merge-base> --to @` to see what changes would land on the {bookmark} bookmark. Provide prioritized, actionable findings.";

const CHANGE_PROMPT_WITH_TITLE =
	'Review the code changes introduced by change {sha} ("{title}"). Provide prioritized, actionable findings.';

const CHANGE_PROMPT = "Review the code changes introduced by change {sha}. Provide prioritized, actionable findings.";

const PULL_REQUEST_PROMPT =
	'Review pull request #{prNumber} ("{title}") against the base bookmark \'{baseBookmark}\'. The merge-base revision for this comparison is {mergeBaseSha}. Run `jj diff --from {mergeBaseSha} --to @` to inspect the changes that would be merged. Provide prioritized, actionable findings.';

const PULL_REQUEST_PROMPT_FALLBACK =
	'Review pull request #{prNumber} ("{title}") against the base bookmark \'{baseBookmark}\'. Start by finding the merge-base revision between the working copy and {baseBookmark}, then run `jj diff --from <merge-base> --to @` to see the changes that would be merged. Provide prioritized, actionable findings.';

const FOLDER_REVIEW_PROMPT =
	"Review the code in the following paths: {paths}. This is a snapshot review (not a diff). Read the files directly in these paths and provide prioritized, actionable findings.";

// The detailed review rubric (adapted from Codex's review_prompt.md)
const REVIEW_RUBRIC = `# Review Guidelines

You are acting as a code reviewer for a proposed code change made by another engineer.

Below are default guidelines for determining what to flag. These are not the final word — if you encounter more specific guidelines elsewhere (in a developer message, user message, file, or project review guidelines appended below), those override these general instructions.

## Determining what to flag

Flag issues that:
1. Meaningfully impact the accuracy, performance, security, or maintainability of the code.
2. Are discrete and actionable (not general issues or multiple combined issues).
3. Don't demand rigor inconsistent with the rest of the codebase.
4. Were introduced in the changes being reviewed (not pre-existing bugs).
5. The author would likely fix if aware of them.
6. Don't rely on unstated assumptions about the codebase or author's intent.
7. Have provable impact on other parts of the code — it is not enough to speculate that a change may disrupt another part, you must identify the parts that are provably affected.
8. Are clearly not intentional changes by the author.
9. Be particularly careful with untrusted user input and follow the specific guidelines to review.
10. Treat silent local error recovery (especially parsing/IO/network fallbacks) as high-signal review candidates unless there is explicit boundary-level justification.

## Untrusted User Input

1. Be careful with open redirects, they must always be checked to only go to trusted domains (?next_page=...)
2. Always flag SQL that is not parametrized
3. In systems with user supplied URL input, http fetches always need to be protected against access to local resources (intercept DNS resolver!)
4. Escape, don't sanitize if you have the option (eg: HTML escaping)

## Comment guidelines

1. Be clear about why the issue is a problem.
2. Communicate severity appropriately - don't exaggerate.
3. Be brief - at most 1 paragraph.
4. Keep code snippets under 3 lines, wrapped in inline code or code blocks.
5. Use \`\`\`suggestion blocks ONLY for concrete replacement code (minimal lines; no commentary inside the block). Preserve the exact leading whitespace of the replaced lines.
6. Explicitly state scenarios/environments where the issue arises.
7. Use a matter-of-fact tone - helpful AI assistant, not accusatory.
8. Write for quick comprehension without close reading.
9. Avoid excessive flattery or unhelpful phrases like "Great job...".

## Review priorities

1. Surface critical non-blocking human callouts (migrations, dependency churn, auth/permissions, compatibility, destructive operations) at the end.
2. Prefer simple, direct solutions over wrappers or abstractions without clear value.
3. Treat back pressure handling as critical to system stability.
4. Apply system-level thinking; flag changes that increase operational risk or on-call wakeups.
5. Ensure that errors are always checked against codes or stable identifiers, never error messages.

## Fail-fast error handling (strict)

When reviewing added or modified error handling, default to fail-fast behavior.

1. Evaluate every new or changed \`try/catch\`: identify what can fail and why local handling is correct at that exact layer.
2. Prefer propagation over local recovery. If the current scope cannot fully recover while preserving correctness, rethrow (optionally with context) instead of returning fallbacks.
3. Flag catch blocks that hide failure signals (e.g. returning \`null\`/\`[]\`/\`false\`, swallowing JSON parse failures, logging-and-continue, or “best effort” silent recovery).
4. JSON parsing/decoding should fail loudly by default. Quiet fallback parsing is only acceptable with an explicit compatibility requirement and clear tested behavior.
5. Boundary handlers (HTTP routes, CLI entrypoints, supervisors) may translate errors, but must not pretend success or silently degrade.
6. If a catch exists only to satisfy lint/style without real handling, treat it as a bug.
7. When uncertain, prefer crashing fast over silent degradation.

## Required human callouts (non-blocking, at the very end)

After findings/verdict, you MUST append this final section:

## Human Reviewer Callouts (Non-Blocking)

Include only applicable callouts (no yes/no lines):

- **This change adds a database migration:** <files/details>
- **This change introduces a new dependency:** <package(s)/details>
- **This change changes a dependency (or the lockfile):** <files/package(s)/details>
- **This change modifies auth/permission behavior:** <what changed and where>
- **This change introduces backwards-incompatible public schema/API/contract changes:** <what changed and where>
- **This change includes irreversible or destructive operations:** <operation and scope>

Rules for this section:
1. These are informational callouts for the human reviewer, not fix items.
2. Do not include them in Findings unless there is an independent defect.
3. These callouts alone must not change the verdict.
4. Only include callouts that apply to the reviewed change.
5. Keep each emitted callout bold exactly as written.
6. If none apply, write "- (none)".

## Priority levels

Tag each finding with a priority level in the title:
- [P0] - Drop everything to fix. Blocking release/operations. Only for universal issues that do not depend on assumptions about inputs.
- [P1] - Urgent. Should be addressed in the next cycle.
- [P2] - Normal. To be fixed eventually.
- [P3] - Low. Nice to have.

## Output format

Provide your findings in a clear, structured format:
1. List each finding with its priority tag, file location, and explanation.
2. Findings must reference locations that overlap with the actual diff — don't flag pre-existing code.
3. Keep line references as short as possible (avoid ranges over 5-10 lines; pick the most suitable subrange).
4. Provide an overall verdict: "correct" (no blocking issues) or "needs attention" (has blocking issues).
5. Ignore trivial style issues unless they obscure meaning or violate documented standards.
6. Do not generate a full PR fix — only flag issues and optionally provide short suggestion blocks.
7. End with the required "Human Reviewer Callouts (Non-Blocking)" section and all applicable bold callouts (no yes/no).

Output all findings the author would fix if they knew about them. If there are no qualifying findings, explicitly state the code looks good. Don't stop at the first finding - list every qualifying issue. Then append the required non-blocking callouts section.`;

async function loadProjectReviewGuidelines(cwd: string): Promise<string | null> {
	let currentDir = path.resolve(cwd);

	while (true) {
		const piDir = path.join(currentDir, ".pi");
		const guidelinesPath = path.join(currentDir, "REVIEW_GUIDELINES.md");

		const piStats = await fs.stat(piDir).catch(() => null);
		if (piStats?.isDirectory()) {
			const guidelineStats = await fs.stat(guidelinesPath).catch(() => null);
			if (guidelineStats?.isFile()) {
				try {
					const content = await fs.readFile(guidelinesPath, "utf8");
					const trimmed = content.trim();
					return trimmed ? trimmed : null;
				} catch {
					return null;
				}
			}
			return null;
		}

		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) {
			return null;
		}
		currentDir = parentDir;
	}
}

function parseNonEmptyLines(stdout: string): string[] {
	return stdout
		.trim()
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean);
}

function quoteRevsetString(value: string): string {
	return JSON.stringify(value);
}

function localBookmarkRevset(bookmark: string): string {
	return `bookmarks(exact:${quoteRevsetString(bookmark)})`;
}

function remoteBookmarkRevset(bookmark: string, remote: string): string {
	return `remote_bookmarks(exact:${quoteRevsetString(bookmark)}, exact:${quoteRevsetString(remote)})`;
}

function bookmarkRefToRevset(bookmark: BookmarkRef): string {
	return bookmark.remote ? remoteBookmarkRevset(bookmark.name, bookmark.remote) : localBookmarkRevset(bookmark.name);
}

function bookmarkRefToLabel(bookmark: BookmarkRef): string {
	return bookmark.remote ? `${bookmark.name}@${bookmark.remote}` : bookmark.name;
}

function bookmarkRefsEqual(left: BookmarkRef, right: BookmarkRef): boolean {
	return left.name === right.name && left.remote === right.remote;
}

function parseBookmarkReference(value: string): BookmarkRef {
	const trimmed = value.trim();
	const separatorIndex = trimmed.lastIndexOf("@");
	if (separatorIndex <= 0 || separatorIndex === trimmed.length - 1) {
		return { name: trimmed };
	}

	return {
		name: trimmed.slice(0, separatorIndex),
		remote: trimmed.slice(separatorIndex + 1),
	};
}

function parseBookmarkRefs(stdout: string): BookmarkRef[] {
	return parseNonEmptyLines(stdout)
		.map((line) => {
			const [name, remote = ""] = line.split("\t");
			return {
				name: name.trim(),
				remote: remote.trim() || undefined,
			};
		})
		.filter((bookmark) => bookmark.name && bookmark.remote !== "git");
}

function dedupeBookmarkRefs(bookmarks: BookmarkRef[]): BookmarkRef[] {
	const seen = new Set<string>();
	const result: BookmarkRef[] = [];

	for (const bookmark of bookmarks) {
		const key = `${bookmark.name}@${bookmark.remote ?? ""}`;
		if (seen.has(key)) {
			continue;
		}

		seen.add(key);
		result.push(bookmark);
	}

	return result;
}

async function getBookmarkRefs(
	pi: ExtensionAPI,
	options?: { revset?: string; includeRemotes?: boolean },
): Promise<BookmarkRef[]> {
	const args = ["bookmark", "list"];
	if (options?.includeRemotes) {
		args.push("--all-remotes");
	}
	if (options?.revset) {
		args.push("-r", options.revset);
	}
	args.push("-T", 'name ++ "\\t" ++ remote ++ "\\n"');

	const { stdout, code } = await pi.exec("jj", args);
	if (code !== 0) return [];
	return dedupeBookmarkRefs(parseBookmarkRefs(stdout));
}

async function getSingleRevisionId(pi: ExtensionAPI, revset: string): Promise<string | null> {
	const { stdout, code } = await pi.exec("jj", ["log", "-r", revset, "--no-graph", "-T", 'commit_id ++ "\\n"']);
	if (code !== 0) {
		return null;
	}

	const revisions = parseNonEmptyLines(stdout);
	if (revisions.length !== 1) {
		return null;
	}

	return revisions[0];
}

async function getDefaultRemoteName(pi: ExtensionAPI): Promise<string | null> {
	const remotes = await getJjRemotes(pi);
	if (remotes.length === 0) {
		return null;
	}

	return remotes.find((remote) => remote.name === "origin")?.name ?? remotes[0].name;
}

function preferBookmarkRef(bookmarks: BookmarkRef[], preferredRemote?: string | null): BookmarkRef | null {
	if (bookmarks.length === 0) {
		return null;
	}

	return (
		bookmarks.find((bookmark) => !bookmark.remote) ??
		(preferredRemote ? bookmarks.find((bookmark) => bookmark.remote === preferredRemote) : undefined) ??
		bookmarks[0]
	);
}

async function resolveBookmarkRef(
	pi: ExtensionAPI,
	bookmark: string,
	remote?: string,
): Promise<BookmarkRef | null> {
	if (remote) {
		return { name: bookmark, remote };
	}

	const localBookmark = (await getBookmarkRefs(pi)).find((entry) => entry.name === bookmark);
	if (localBookmark) {
		return localBookmark;
	}

	const matchingRemoteBookmarks = (await getBookmarkRefs(pi, { includeRemotes: true })).filter(
		(entry) => entry.remote && entry.name === bookmark,
	);
	if (matchingRemoteBookmarks.length === 0) {
		return null;
	}

	return preferBookmarkRef(matchingRemoteBookmarks, await getDefaultRemoteName(pi));
}

async function getReviewBookmarks(pi: ExtensionAPI): Promise<BookmarkRef[]> {
	const localBookmarks = await getBookmarkRefs(pi);
	const localNames = new Set(localBookmarks.map((bookmark) => bookmark.name));
	const defaultRemoteName = await getDefaultRemoteName(pi);
	const remoteOnlyBookmarks = (await getBookmarkRefs(pi, { includeRemotes: true }))
		.filter((bookmark) => bookmark.remote && !localNames.has(bookmark.name))
		.sort((left, right) => {
			if (left.name !== right.name) {
				return left.name.localeCompare(right.name);
			}
			if (left.remote === defaultRemoteName) return -1;
			if (right.remote === defaultRemoteName) return 1;
			return (left.remote ?? "").localeCompare(right.remote ?? "");
		});

	return dedupeBookmarkRefs([...localBookmarks, ...remoteOnlyBookmarks]);
}

async function getReviewHeadRevset(pi: ExtensionAPI): Promise<string> {
	return (await hasWorkingCopyChanges(pi)) ? "@" : "@-";
}

async function getCurrentReviewBookmarks(pi: ExtensionAPI): Promise<BookmarkRef[]> {
	return getBookmarkRefs(pi, {
		revset: await getReviewHeadRevset(pi),
		includeRemotes: true,
	});
}

async function getDefaultBookmarkRef(pi: ExtensionAPI): Promise<BookmarkRef | null> {
	const defaultRemoteName = await getDefaultRemoteName(pi);
	const trunkBookmarks = await getBookmarkRefs(pi, { revset: "trunk()", includeRemotes: true });
	const trunkBookmark = preferBookmarkRef(trunkBookmarks, defaultRemoteName);
	if (trunkBookmark) {
		return trunkBookmark;
	}

	const bookmarks = await getReviewBookmarks(pi);
	const mainBookmark =
		bookmarks.find((bookmark) => !bookmark.remote && bookmark.name === "main") ??
		bookmarks.find((bookmark) => !bookmark.remote && bookmark.name === "master") ??
		bookmarks.find((bookmark) => bookmark.remote === defaultRemoteName && bookmark.name === "main") ??
		bookmarks.find((bookmark) => bookmark.remote === defaultRemoteName && bookmark.name === "master");
	if (mainBookmark) {
		return mainBookmark;
	}

	return bookmarks[0] ?? null;
}

/**
 * Get the merge-base revision between the working copy and a bookmark
 */
async function getMergeBase(
	pi: ExtensionAPI,
	bookmark: string,
	remote?: string,
): Promise<string | null> {
	try {
		const bookmarkRef = await resolveBookmarkRef(pi, bookmark, remote);
		if (!bookmarkRef) {
			return null;
		}

		return getSingleRevisionId(pi, `heads(::@ & ::${bookmarkRefToRevset(bookmarkRef)})`);
	} catch {
		return null;
	}
}

/**
 * Get list of recent changes
 */
async function getRecentChanges(pi: ExtensionAPI, limit: number = 10): Promise<Array<{ sha: string; title: string }>> {
	const { stdout, code } = await pi.exec("jj", [
		"log",
		"-n",
		`${limit}`,
		"--no-graph",
		"-T",
		'commit_id ++ "\\t" ++ description.first_line() ++ "\\n"',
	]);
	if (code !== 0) return [];

	return parseNonEmptyLines(stdout)
		.filter((line) => line.trim())
		.map((line) => {
			const [sha, ...rest] = line.trim().split("\t");
			return { sha, title: rest.join(" ") };
		});
}

/**
 * Check if there are working-copy changes
 */
async function hasWorkingCopyChanges(pi: ExtensionAPI): Promise<boolean> {
	const { stdout, code } = await pi.exec("jj", ["diff", "--summary"]);
	return code === 0 && stdout.trim().length > 0;
}

/**
 * Check if there are local changes that would make switching bookmarks surprising
 */
async function hasPendingChanges(pi: ExtensionAPI): Promise<boolean> {
	return hasWorkingCopyChanges(pi);
}

/**
 * Parse a PR reference (URL or number) and return the PR number
 */
function parsePrReference(ref: string): number | null {
	const trimmed = ref.trim();

	// Try as a number first
	const num = parseInt(trimmed, 10);
	if (!isNaN(num) && num > 0) {
		return num;
	}

	// Try to extract from GitHub URL
	// Formats: https://github.com/owner/repo/pull/123
	//          github.com/owner/repo/pull/123
	const urlMatch = trimmed.match(/github\.com\/[^/]+\/[^/]+\/pull\/(\d+)/);
	if (urlMatch) {
		return parseInt(urlMatch[1], 10);
	}

	return null;
}

/**
 * Get PR information from GitHub CLI
 */
async function getPrInfo(
	pi: ExtensionAPI,
	prNumber: number,
): Promise<{
	baseBookmark: string;
	title: string;
	headBookmark: string;
	isCrossRepository: boolean;
	headRepositoryName?: string;
	headRepositoryOwner?: string;
	headRepositoryUrl?: string;
} | null> {
	const { stdout, code } = await pi.exec("gh", [
		"pr", "view", String(prNumber),
		"--json", "baseRefName,title,headRefName,isCrossRepository,headRepository,headRepositoryOwner",
	]);

	if (code !== 0) return null;

	try {
		const data = JSON.parse(stdout);
		return {
			baseBookmark: data.baseRefName,
			title: data.title,
			headBookmark: data.headRefName,
			isCrossRepository: data.isCrossRepository === true,
			headRepositoryName: data.headRepository?.name,
			headRepositoryOwner: data.headRepositoryOwner?.login,
			headRepositoryUrl: data.headRepository?.url,
		};
	} catch {
		return null;
	}
}

/**
 * Get configured jj remotes
 */
async function getJjRemotes(pi: ExtensionAPI): Promise<Array<{ name: string; url: string }>> {
	const { stdout, code } = await pi.exec("jj", ["git", "remote", "list"]);
	if (code !== 0) return [];

	return parseNonEmptyLines(stdout)
		.map((line) => {
			const [name, ...urlParts] = line.split(/\s+/);
			return { name, url: urlParts.join(" ") };
		})
		.filter((remote) => remote.name && remote.url);
}

function normalizeRemoteUrl(value: string): string {
	return value
		.trim()
		.replace(/^git@github\.com:/, "https://github.com/")
		.replace(/^ssh:\/\/git@github\.com\//, "https://github.com/")
		.replace(/\.git$/, "")
		.toLowerCase();
}

function sanitizeRemoteName(value: string): string {
	const sanitized = value.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
	return sanitized || "gh-pr";
}

/**
 * Materialize a PR locally with jj
 */
async function materializePr(
	pi: ExtensionAPI,
	prNumber: number,
	prInfo: {
		headBookmark: string;
		isCrossRepository: boolean;
		headRepositoryName?: string;
		headRepositoryOwner?: string;
		headRepositoryUrl?: string;
	},
): Promise<{ success: boolean; remote?: string; error?: string }> {
	const defaultRemoteName = await getDefaultRemoteName(pi);
	if (!defaultRemoteName) {
		return { success: false, error: "No jj remotes are configured for this repository" };
	}

	const existingRemotes = await getJjRemotes(pi);
	let remoteName = defaultRemoteName;
	let addedTemporaryRemote = false;

	if (prInfo.isCrossRepository) {
		const repoSlug = prInfo.headRepositoryOwner && prInfo.headRepositoryName
			? `${prInfo.headRepositoryOwner}/${prInfo.headRepositoryName}`.toLowerCase()
			: undefined;
		const existingRemote = existingRemotes.find((remote) => {
			if (prInfo.headRepositoryUrl && normalizeRemoteUrl(remote.url) === normalizeRemoteUrl(prInfo.headRepositoryUrl)) {
				return true;
			}
			return repoSlug ? normalizeRemoteUrl(remote.url).includes(`github.com/${repoSlug}`) : false;
		});

		if (existingRemote) {
			remoteName = existingRemote.name;
		} else if (prInfo.headRepositoryUrl) {
			const remoteBaseName = sanitizeRemoteName(
				`gh-pr-${prInfo.headRepositoryOwner ?? "remote"}-${prInfo.headRepositoryName ?? prNumber}`,
			);
			const existingRemoteNames = new Set(existingRemotes.map((remote) => remote.name));
			remoteName = remoteBaseName;
			let suffix = 2;
			while (existingRemoteNames.has(remoteName)) {
				remoteName = `${remoteBaseName}-${suffix}`;
				suffix += 1;
			}
			const addRemoteResult = await pi.exec("jj", ["git", "remote", "add", remoteName, prInfo.headRepositoryUrl]);
			if (addRemoteResult.code !== 0) {
				return { success: false, error: addRemoteResult.stderr || addRemoteResult.stdout || "Failed to add PR remote" };
			}
			addedTemporaryRemote = true;
		} else {
			return { success: false, error: "PR head repository URL is unavailable" };
		}
	}

	const fetchResult = await pi.exec("jj", ["git", "fetch", "--remote", remoteName, "--branch", prInfo.headBookmark]);
	if (fetchResult.code !== 0) {
		if (addedTemporaryRemote) {
			await pi.exec("jj", ["git", "remote", "remove", remoteName]);
		}
		return { success: false, error: fetchResult.stderr || fetchResult.stdout || "Failed to fetch PR bookmark" };
	}

	const editResult = await pi.exec("jj", ["new", remoteBookmarkRevset(prInfo.headBookmark, remoteName)]);
	if (editResult.code !== 0) {
		if (addedTemporaryRemote) {
			await pi.exec("jj", ["git", "remote", "remove", remoteName]);
		}
		return { success: false, error: editResult.stderr || editResult.stdout || "Failed to materialize PR locally" };
	}

	if (addedTemporaryRemote) {
		await pi.exec("jj", ["git", "remote", "remove", remoteName]);
	}

	return { success: true, remote: remoteName };
}

/**
 * Build the review prompt based on target
 */
async function buildReviewPrompt(
	pi: ExtensionAPI,
	target: ReviewTarget,
	options?: { includeLocalChanges?: boolean },
): Promise<string> {
	const includeLocalChanges = options?.includeLocalChanges === true;

	switch (target.type) {
		case "workingCopy":
			return WORKING_COPY_PROMPT;

		case "baseBookmark": {
			const bookmarkLabel = bookmarkRefToLabel({ name: target.bookmark, remote: target.remote });
			const mergeBase = await getMergeBase(pi, target.bookmark, target.remote);
			const basePrompt = mergeBase
				? BASE_BOOKMARK_PROMPT_WITH_MERGE_BASE
						.replace(/{baseBookmark}/g, bookmarkLabel)
						.replace(/{mergeBaseSha}/g, mergeBase)
				: BASE_BOOKMARK_PROMPT_FALLBACK.replace(/{bookmark}/g, bookmarkLabel);
			return includeLocalChanges ? `${basePrompt} ${LOCAL_CHANGES_REVIEW_INSTRUCTIONS}` : basePrompt;
		}

		case "change":
			if (target.title) {
				return CHANGE_PROMPT_WITH_TITLE.replace("{sha}", target.sha).replace("{title}", target.title);
			}
			return CHANGE_PROMPT.replace("{sha}", target.sha);

		case "pullRequest": {
			const baseBookmarkLabel = bookmarkRefToLabel({ name: target.baseBookmark, remote: target.baseRemote });
			const mergeBase = await getMergeBase(pi, target.baseBookmark, target.baseRemote);
			const basePrompt = mergeBase
				? PULL_REQUEST_PROMPT
						.replace(/{prNumber}/g, String(target.prNumber))
						.replace(/{title}/g, target.title)
						.replace(/{baseBookmark}/g, baseBookmarkLabel)
						.replace(/{mergeBaseSha}/g, mergeBase)
				: PULL_REQUEST_PROMPT_FALLBACK
						.replace(/{prNumber}/g, String(target.prNumber))
						.replace(/{title}/g, target.title)
						.replace(/{baseBookmark}/g, baseBookmarkLabel);
			return includeLocalChanges ? `${basePrompt} ${LOCAL_CHANGES_REVIEW_INSTRUCTIONS}` : basePrompt;
		}

		case "folder":
			return FOLDER_REVIEW_PROMPT.replace("{paths}", target.paths.join(", "));
	}
}

/**
 * Get user-facing hint for the review target
 */
function getUserFacingHint(target: ReviewTarget): string {
	switch (target.type) {
		case "workingCopy":
			return "working-copy changes";
		case "baseBookmark":
			return `changes against '${bookmarkRefToLabel({ name: target.bookmark, remote: target.remote })}'`;
		case "change": {
			const shortSha = target.sha.slice(0, 7);
			return target.title ? `change ${shortSha}: ${target.title}` : `change ${shortSha}`;
		}

		case "pullRequest": {
			const shortTitle = target.title.length > 30 ? target.title.slice(0, 27) + "..." : target.title;
			return `PR #${target.prNumber}: ${shortTitle}`;
		}

		case "folder": {
			const joined = target.paths.join(", ");
			return joined.length > 40 ? `folders: ${joined.slice(0, 37)}...` : `folders: ${joined}`;
		}
	}
}

type AssistantSnapshot = {
	id: string;
	text: string;
	stopReason?: string;
};

function extractAssistantTextContent(content: unknown): string {
	if (typeof content === "string") {
		return content.trim();
	}

	if (!Array.isArray(content)) {
		return "";
	}

	const textParts = content
		.filter(
			(part): part is { type: "text"; text: string } =>
				Boolean(part && typeof part === "object" && "type" in part && part.type === "text" && "text" in part),
		)
		.map((part) => part.text);
	return textParts.join("\n").trim();
}

function getLastAssistantSnapshot(ctx: ExtensionContext): AssistantSnapshot | null {
	const entries = ctx.sessionManager.getBranch();
	for (let i = entries.length - 1; i >= 0; i--) {
		const entry = entries[i];
		if (entry.type !== "message" || entry.message.role !== "assistant") {
			continue;
		}

		const assistantMessage = entry.message as { content?: unknown; stopReason?: string };
		return {
			id: entry.id,
			text: extractAssistantTextContent(assistantMessage.content),
			stopReason: assistantMessage.stopReason,
		};
	}

	return null;
}

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForLoopTurnToStart(ctx: ExtensionContext, previousAssistantId?: string): Promise<boolean> {
	const deadline = Date.now() + REVIEW_LOOP_START_TIMEOUT_MS;

	while (Date.now() < deadline) {
		const lastAssistantId = getLastAssistantSnapshot(ctx)?.id;
		if (!ctx.isIdle() || ctx.hasPendingMessages() || (lastAssistantId && lastAssistantId !== previousAssistantId)) {
			return true;
		}
		await sleep(REVIEW_LOOP_START_POLL_MS);
	}

	return false;
}

// Review preset options for the selector (keep this order stable)
const REVIEW_PRESETS = [
	{ value: "workingCopy", label: "Review working-copy changes", description: "" },
	{ value: "baseBookmark", label: "Review against a base bookmark", description: "(local)" },
	{ value: "change", label: "Review a change", description: "" },
	{ value: "pullRequest", label: "Review a pull request", description: "(GitHub PR)" },
	{ value: "folder", label: "Review a folder (or more)", description: "(snapshot, not diff)" },
] as const;

const TOGGLE_LOOP_FIXING_VALUE = "toggleLoopFixing" as const;
const TOGGLE_CUSTOM_INSTRUCTIONS_VALUE = "toggleCustomInstructions" as const;
type ReviewPresetValue =
	| (typeof REVIEW_PRESETS)[number]["value"]
	| typeof TOGGLE_LOOP_FIXING_VALUE
	| typeof TOGGLE_CUSTOM_INSTRUCTIONS_VALUE;

export default function reviewExtension(pi: ExtensionAPI) {
	function persistReviewSettings() {
		pi.appendEntry(REVIEW_SETTINGS_TYPE, {
			loopFixingEnabled: reviewLoopFixingEnabled,
			customInstructions: reviewCustomInstructions,
		});
	}

	function setReviewLoopFixingEnabled(enabled: boolean) {
		reviewLoopFixingEnabled = enabled;
		persistReviewSettings();
	}

	function setReviewCustomInstructions(instructions: string | undefined) {
		reviewCustomInstructions = instructions?.trim() || undefined;
		persistReviewSettings();
	}

	function applyAllReviewState(ctx: ExtensionContext) {
		applyReviewSettings(ctx);
		applyReviewState(ctx);
	}

	pi.on("session_start", (_event, ctx) => {
		applyAllReviewState(ctx);
	});

	pi.on("session_switch", (_event, ctx) => {
		applyAllReviewState(ctx);
	});

	pi.on("session_tree", (_event, ctx) => {
		applyAllReviewState(ctx);
	});

	/**
	 * Determine the smart default review type based on jj state
	 */
	async function getSmartDefault(): Promise<"workingCopy" | "baseBookmark" | "change"> {
		// Priority 1: If there are working-copy changes, default to reviewing them
		if (await hasWorkingCopyChanges(pi)) {
			return "workingCopy";
		}

		// Priority 2: If the current review head differs from trunk/default, default to bookmark-style review
		const defaultBookmark = await getDefaultBookmarkRef(pi);
		if (defaultBookmark) {
			const reviewHeadRevision = await getSingleRevisionId(pi, await getReviewHeadRevset(pi));
			const defaultBookmarkRevision = await getSingleRevisionId(pi, bookmarkRefToRevset(defaultBookmark));
			if (reviewHeadRevision && defaultBookmarkRevision && reviewHeadRevision !== defaultBookmarkRevision) {
				return "baseBookmark";
			}
		}

		// Priority 3: Default to reviewing a specific change
		return "change";
	}

	/**
	 * Show the review preset selector
	 */
	async function showReviewSelector(ctx: ExtensionContext): Promise<ReviewTarget | null> {
		// Determine smart default (but keep the list order stable)
		const smartDefault = await getSmartDefault();
		const presetItems: SelectItem[] = REVIEW_PRESETS.map((preset) => ({
			value: preset.value,
			label: preset.label,
			description: preset.description,
		}));
		const smartDefaultIndex = presetItems.findIndex((item) => item.value === smartDefault);

		while (true) {
			const customInstructionsLabel = reviewCustomInstructions
				? "Remove custom review instructions"
				: "Add custom review instructions";
			const customInstructionsDescription = reviewCustomInstructions
				? "(currently set)"
				: "(applies to all review modes)";
			const loopToggleLabel = reviewLoopFixingEnabled ? "Disable Loop Fixing" : "Enable Loop Fixing";
			const loopToggleDescription = reviewLoopFixingEnabled ? "(currently on)" : "(currently off)";
			const items: SelectItem[] = [
				...presetItems,
				{
					value: TOGGLE_CUSTOM_INSTRUCTIONS_VALUE,
					label: customInstructionsLabel,
					description: customInstructionsDescription,
				},
				{ value: TOGGLE_LOOP_FIXING_VALUE, label: loopToggleLabel, description: loopToggleDescription },
			];

			const result = await ctx.ui.custom<ReviewPresetValue | null>((tui, theme, _kb, done) => {
				const container = new Container();
				container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));
				container.addChild(new Text(theme.fg("accent", theme.bold("Select a review preset"))));

				const selectList = new SelectList(items, Math.min(items.length, 10), {
					selectedPrefix: (text) => theme.fg("accent", text),
					selectedText: (text) => theme.fg("accent", text),
					description: (text) => theme.fg("muted", text),
					scrollInfo: (text) => theme.fg("dim", text),
					noMatch: (text) => theme.fg("warning", text),
				});

				// Preselect the smart default without reordering the list
				if (smartDefaultIndex >= 0) {
					selectList.setSelectedIndex(smartDefaultIndex);
				}

				selectList.onSelect = (item) => done(item.value as ReviewPresetValue);
				selectList.onCancel = () => done(null);

				container.addChild(selectList);
				container.addChild(new Text(theme.fg("dim", "Press enter to confirm or esc to go back")));
				container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));

				return {
					render(width: number) {
						return container.render(width);
					},
					invalidate() {
						container.invalidate();
					},
					handleInput(data: string) {
						selectList.handleInput(data);
						tui.requestRender();
					},
				};
			});

			if (!result) return null;

			if (result === TOGGLE_LOOP_FIXING_VALUE) {
				const nextEnabled = !reviewLoopFixingEnabled;
				setReviewLoopFixingEnabled(nextEnabled);
				ctx.ui.notify(nextEnabled ? "Loop fixing enabled" : "Loop fixing disabled", "info");
				continue;
			}

			if (result === TOGGLE_CUSTOM_INSTRUCTIONS_VALUE) {
				if (reviewCustomInstructions) {
					setReviewCustomInstructions(undefined);
					ctx.ui.notify("Custom review instructions removed", "info");
					continue;
				}

				const customInstructions = await ctx.ui.editor(
					"Enter custom review instructions (applies to all review modes):",
					"",
				);

				if (!customInstructions?.trim()) {
					ctx.ui.notify("Custom review instructions not changed", "info");
					continue;
				}

				setReviewCustomInstructions(customInstructions);
				ctx.ui.notify("Custom review instructions saved", "info");
				continue;
			}

			// Handle each preset type
			switch (result) {
				case "workingCopy":
					return { type: "workingCopy" };

				case "baseBookmark": {
					const target = await showBookmarkSelector(ctx);
					if (target) return target;
					break;
				}

				case "change": {
					if (reviewLoopFixingEnabled) {
						ctx.ui.notify("Loop mode does not work with change review.", "error");
						break;
					}
					const target = await showChangeSelector(ctx);
					if (target) return target;
					break;
				}

				case "folder": {
					const target = await showFolderInput(ctx);
					if (target) return target;
					break;
				}

				case "pullRequest": {
					const target = await showPrInput(ctx);
					if (target) return target;
					break;
				}

				default:
					return null;
			}
		}
	}

	/**
	 * Show bookmark selector for base bookmark review
	 */
	async function showBookmarkSelector(ctx: ExtensionContext): Promise<ReviewTarget | null> {
		const bookmarks = await getReviewBookmarks(pi);
		const currentBookmarks = await getCurrentReviewBookmarks(pi);
		const defaultBookmark = await getDefaultBookmarkRef(pi);

		// Never offer the current review head's bookmark(s) as the base bookmark.
		const candidateBookmarks = bookmarks.filter(
			(bookmark) => !currentBookmarks.some((currentBookmark) => bookmarkRefsEqual(bookmark, currentBookmark)),
		);

		if (candidateBookmarks.length === 0) {
			const currentLabel = currentBookmarks[0] ? bookmarkRefToLabel(currentBookmarks[0]) : undefined;
			ctx.ui.notify(
				currentLabel ? `No other bookmarks found (current bookmark: ${currentLabel})` : "No bookmarks found",
				"error",
			);
			return null;
		}

		// Sort bookmarks with the default bookmark first, then local bookmarks before remote-only ones.
		const sortedBookmarks = candidateBookmarks.sort((a, b) => {
			if (defaultBookmark && bookmarkRefsEqual(a, defaultBookmark)) return -1;
			if (defaultBookmark && bookmarkRefsEqual(b, defaultBookmark)) return 1;
			if (!!a.remote !== !!b.remote) return a.remote ? 1 : -1;
			return bookmarkRefToLabel(a).localeCompare(bookmarkRefToLabel(b));
		});

		const items: SelectItem[] = sortedBookmarks.map((bookmark) => ({
			value: bookmarkRefToLabel(bookmark),
			label: bookmarkRefToLabel(bookmark),
			description: defaultBookmark && bookmarkRefsEqual(bookmark, defaultBookmark)
				? "(default)"
				: bookmark.remote
					? `(remote ${bookmark.remote})`
					: "",
		}));

		const result = await ctx.ui.custom<string | null>((tui, theme, keybindings, done) => {
			const container = new Container();
			container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));
			container.addChild(new Text(theme.fg("accent", theme.bold("Select base bookmark"))));

			const searchInput = new Input();
			container.addChild(searchInput);
			container.addChild(new Spacer(1));

			const listContainer = new Container();
			container.addChild(listContainer);
			container.addChild(new Text(theme.fg("dim", "Type to filter • enter to select • esc to cancel")));
			container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));

			let filteredItems = items;
			let selectList: SelectList | null = null;

			const updateList = () => {
				listContainer.clear();
				if (filteredItems.length === 0) {
					listContainer.addChild(new Text(theme.fg("warning", "  No matching bookmarks")));
					selectList = null;
					return;
				}

				selectList = new SelectList(filteredItems, Math.min(filteredItems.length, 10), {
					selectedPrefix: (text) => theme.fg("accent", text),
					selectedText: (text) => theme.fg("accent", text),
					description: (text) => theme.fg("muted", text),
					scrollInfo: (text) => theme.fg("dim", text),
					noMatch: (text) => theme.fg("warning", text),
				});

				selectList.onSelect = (item) => done(item.value);
				selectList.onCancel = () => done(null);
				listContainer.addChild(selectList);
			};

			const applyFilter = () => {
				const query = searchInput.getValue();
				filteredItems = query
					? fuzzyFilter(items, query, (item) => `${item.label} ${item.value} ${item.description ?? ""}`)
					: items;
				updateList();
			};

			applyFilter();

			return {
				render(width: number) {
					return container.render(width);
				},
				invalidate() {
					container.invalidate();
				},
				handleInput(data: string) {
					if (
						keybindings.matches(data, "tui.select.up") ||
						keybindings.matches(data, "tui.select.down") ||
						keybindings.matches(data, "tui.select.confirm") ||
						keybindings.matches(data, "tui.select.cancel")
					) {
						if (selectList) {
							selectList.handleInput(data);
						} else if (keybindings.matches(data, "tui.select.cancel")) {
							done(null);
						}
						tui.requestRender();
						return;
					}

					searchInput.handleInput(data);
					applyFilter();
					tui.requestRender();
				},
			};
		});

		if (!result) return null;
		const bookmark = parseBookmarkReference(result);
		return { type: "baseBookmark", bookmark: bookmark.name, remote: bookmark.remote };
	}

	/**
	 * Show change selector
	 */
	async function showChangeSelector(ctx: ExtensionContext): Promise<ReviewTarget | null> {
		const changes = await getRecentChanges(pi, 20);

		if (changes.length === 0) {
			ctx.ui.notify("No changes found", "error");
			return null;
		}

		const items: SelectItem[] = changes.map((change) => ({
			value: change.sha,
			label: `${change.sha.slice(0, 7)} ${change.title}`,
			description: "",
		}));

		const result = await ctx.ui.custom<{ sha: string; title: string } | null>((tui, theme, keybindings, done) => {
			const container = new Container();
			container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));
			container.addChild(new Text(theme.fg("accent", theme.bold("Select change to review"))));

			const searchInput = new Input();
			container.addChild(searchInput);
			container.addChild(new Spacer(1));

			const listContainer = new Container();
			container.addChild(listContainer);
			container.addChild(new Text(theme.fg("dim", "Type to filter • enter to select • esc to cancel")));
			container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));

			let filteredItems = items;
			let selectList: SelectList | null = null;

			const updateList = () => {
				listContainer.clear();
				if (filteredItems.length === 0) {
					listContainer.addChild(new Text(theme.fg("warning", "  No matching changes")));
					selectList = null;
					return;
				}

				selectList = new SelectList(filteredItems, Math.min(filteredItems.length, 10), {
					selectedPrefix: (text) => theme.fg("accent", text),
					selectedText: (text) => theme.fg("accent", text),
					description: (text) => theme.fg("muted", text),
					scrollInfo: (text) => theme.fg("dim", text),
					noMatch: (text) => theme.fg("warning", text),
				});

				selectList.onSelect = (item) => {
					const change = changes.find((c) => c.sha === item.value);
					if (change) {
						done(change);
					} else {
						done(null);
					}
				};
				selectList.onCancel = () => done(null);
				listContainer.addChild(selectList);
			};

			const applyFilter = () => {
				const query = searchInput.getValue();
				filteredItems = query
					? fuzzyFilter(items, query, (item) => `${item.label} ${item.value} ${item.description ?? ""}`)
					: items;
				updateList();
			};

			applyFilter();

			return {
				render(width: number) {
					return container.render(width);
				},
				invalidate() {
					container.invalidate();
				},
				handleInput(data: string) {
					if (
						keybindings.matches(data, "tui.select.up") ||
						keybindings.matches(data, "tui.select.down") ||
						keybindings.matches(data, "tui.select.confirm") ||
						keybindings.matches(data, "tui.select.cancel")
					) {
						if (selectList) {
							selectList.handleInput(data);
						} else if (keybindings.matches(data, "tui.select.cancel")) {
							done(null);
						}
						tui.requestRender();
						return;
					}

					searchInput.handleInput(data);
					applyFilter();
					tui.requestRender();
				},
			};
		});

		if (!result) return null;
		return { type: "change", sha: result.sha, title: result.title };
	}


	function parseReviewPaths(value: string): string[] {
		return value
			.split(/\s+/)
			.map((item) => item.trim())
			.filter((item) => item.length > 0);
	}

	/**
	 * Show folder input
	 */
	async function showFolderInput(ctx: ExtensionContext): Promise<ReviewTarget | null> {
		const result = await ctx.ui.editor(
			"Enter folders/files to review (space-separated or one per line):",
			".",
		);

		if (!result?.trim()) return null;
		const paths = parseReviewPaths(result);
		if (paths.length === 0) return null;

		return { type: "folder", paths };
	}

	/**
	 * Show PR input and materialize the PR locally
	 */
	async function showPrInput(ctx: ExtensionContext): Promise<ReviewTarget | null> {
		// First check for pending changes that would make bookmark switching surprising
		if (await hasPendingChanges(pi)) {
			ctx.ui.notify("Cannot materialize PR: you have local jj changes. Please snapshot or discard them first.", "error");
			return null;
		}

		// Get PR reference from user
		const prRef = await ctx.ui.editor(
			"Enter PR number or URL (e.g. 123 or https://github.com/owner/repo/pull/123):",
			"",
		);

		if (!prRef?.trim()) return null;

		const prNumber = parsePrReference(prRef);
		if (!prNumber) {
			ctx.ui.notify("Invalid PR reference. Enter a number or GitHub PR URL.", "error");
			return null;
		}

		// Get PR info from GitHub
		ctx.ui.notify(`Fetching PR #${prNumber} info...`, "info");
		const prInfo = await getPrInfo(pi, prNumber);

		if (!prInfo) {
			ctx.ui.notify(`Could not find PR #${prNumber}. Make sure gh is authenticated and the PR exists.`, "error");
			return null;
		}

		// Check again for pending changes (in case something changed)
		if (await hasPendingChanges(pi)) {
			ctx.ui.notify("Cannot materialize PR: you have local jj changes. Please snapshot or discard them first.", "error");
			return null;
		}

		// Materialize the PR locally with jj
		ctx.ui.notify(`Materializing PR #${prNumber} with jj...`, "info");
		const materializeResult = await materializePr(pi, prNumber, prInfo);

		if (!materializeResult.success) {
			ctx.ui.notify(`Failed to materialize PR: ${materializeResult.error}`, "error");
			return null;
		}

		ctx.ui.notify(`Materialized PR #${prNumber} (${prInfo.headBookmark}@${materializeResult.remote ?? "origin"})`, "info");

		const baseBookmarkRef = await resolveBookmarkRef(pi, prInfo.baseBookmark);

		return {
			type: "pullRequest",
			prNumber,
			baseBookmark: prInfo.baseBookmark,
			baseRemote: baseBookmarkRef?.remote,
			title: prInfo.title,
		};
	}

	/**
	 * Execute the review
	 */
	async function executeReview(
		ctx: ExtensionCommandContext,
		target: ReviewTarget,
		useFreshSession: boolean,
		options?: { includeLocalChanges?: boolean; extraInstruction?: string },
	): Promise<boolean> {
		// Check if we're already in a review
		if (reviewOriginId) {
			ctx.ui.notify("Already in a review. Use /end-review to finish first.", "warning");
			return false;
		}

		// Handle fresh session mode
		if (useFreshSession) {
			// Store current position (where we'll return to).
			// In an empty session there is no leaf yet, so create a lightweight anchor first.
			let originId = ctx.sessionManager.getLeafId() ?? undefined;
			if (!originId) {
				pi.appendEntry(REVIEW_ANCHOR_TYPE, { createdAt: new Date().toISOString() });
				originId = ctx.sessionManager.getLeafId() ?? undefined;
			}
			if (!originId) {
				ctx.ui.notify("Failed to determine review origin.", "error");
				return false;
			}
			reviewOriginId = originId;

			// Keep a local copy so session_tree events during navigation don't wipe it
			const lockedOriginId = originId;

			// Find the first user message in the session.
			// If none exists (e.g. brand-new session), we'll stay on the current leaf.
			const entries = ctx.sessionManager.getEntries();
			const firstUserMessage = entries.find(
				(e) => e.type === "message" && e.message.role === "user",
			);

			if (firstUserMessage) {
				// Navigate to first user message to create a new branch from that point
				// Label it as "code-review" so it's visible in the tree
				try {
					const result = await ctx.navigateTree(firstUserMessage.id, { summarize: false, label: "code-review" });
					if (result.cancelled) {
						reviewOriginId = undefined;
						return false;
					}
				} catch (error) {
					// Clean up state if navigation fails
					reviewOriginId = undefined;
					ctx.ui.notify(`Failed to start review: ${error instanceof Error ? error.message : String(error)}`, "error");
					return false;
				}

				// Clear the editor (navigating to user message fills it with the message text)
				ctx.ui.setEditorText("");
			}

			// Restore origin after navigation events (session_tree can reset it)
			reviewOriginId = lockedOriginId;

			// Show widget indicating review is active
			setReviewWidget(ctx, true);

			// Persist review state so tree navigation can restore/reset it
			pi.appendEntry(REVIEW_STATE_TYPE, { active: true, originId: lockedOriginId });
		}

		const prompt = await buildReviewPrompt(pi, target, {
			includeLocalChanges: options?.includeLocalChanges === true,
		});
		const hint = getUserFacingHint(target);
		const projectGuidelines = await loadProjectReviewGuidelines(ctx.cwd);

		// Combine the review rubric with the specific prompt
		let fullPrompt = `${REVIEW_RUBRIC}\n\n---\n\nPlease perform a code review with the following focus:\n\n${prompt}`;

		if (reviewCustomInstructions) {
			fullPrompt += `\n\nShared custom review instructions (applies to all reviews):\n\n${reviewCustomInstructions}`;
		}

		if (options?.extraInstruction?.trim()) {
			fullPrompt += `\n\nAdditional user-provided review instruction:\n\n${options.extraInstruction.trim()}`;
		}

		if (projectGuidelines) {
			fullPrompt += `\n\nThis project has additional instructions for code reviews:\n\n${projectGuidelines}`;
		}

		const modeHint = useFreshSession ? " (fresh session)" : "";
		ctx.ui.notify(`Starting review: ${hint}${modeHint}`, "info");

		// Send as a user message that triggers a turn
		pi.sendUserMessage(fullPrompt);
		return true;
	}

	/**
	 * Parse command arguments for direct invocation
	 * Returns the target or a special marker for PR that needs async handling
	 */
	type ParsedReviewArgs = {
		target: ReviewTarget | { type: "pr"; ref: string } | null;
		extraInstruction?: string;
		error?: string;
	};

	function tokenizeArgs(value: string): string[] {
		const tokens: string[] = [];
		let current = "";
		let quote: '"' | "'" | null = null;

		for (let i = 0; i < value.length; i++) {
			const char = value[i];

			if (quote) {
				if (char === "\\" && i + 1 < value.length) {
					current += value[i + 1];
					i += 1;
					continue;
				}
				if (char === quote) {
					quote = null;
					continue;
				}
				current += char;
				continue;
			}

			if (char === '"' || char === "'") {
				quote = char;
				continue;
			}

			if (/\s/.test(char)) {
				if (current.length > 0) {
					tokens.push(current);
					current = "";
				}
				continue;
			}

			current += char;
		}

		if (current.length > 0) {
			tokens.push(current);
		}

		return tokens;
	}

	function parseArgs(args: string | undefined): ParsedReviewArgs {
		if (!args?.trim()) return { target: null };

		const rawParts = tokenizeArgs(args.trim());
		const parts: string[] = [];
		let extraInstruction: string | undefined;

		for (let i = 0; i < rawParts.length; i++) {
			const part = rawParts[i];
			if (part === "--extra") {
				const next = rawParts[i + 1];
				if (!next) {
					return { target: null, error: "Missing value for --extra" };
				}
				extraInstruction = next;
				i += 1;
				continue;
			}

			if (part.startsWith("--extra=")) {
				extraInstruction = part.slice("--extra=".length);
				continue;
			}

			parts.push(part);
		}

		if (parts.length === 0) {
			return { target: null, extraInstruction };
		}

		const subcommand = parts[0]?.toLowerCase();

		switch (subcommand) {
			case "working-copy":
				return { target: { type: "workingCopy" }, extraInstruction };

			case "bookmark": {
				const bookmark = parts[1];
				if (!bookmark) return { target: null, extraInstruction };
				const bookmarkRef = parseBookmarkReference(bookmark);
				return {
					target: { type: "baseBookmark", bookmark: bookmarkRef.name, remote: bookmarkRef.remote },
					extraInstruction,
				};
			}

			case "change": {
				const sha = parts[1];
				if (!sha) return { target: null, extraInstruction };
				const title = parts.slice(2).join(" ") || undefined;
				return { target: { type: "change", sha, title }, extraInstruction };
			}


			case "folder": {
				const paths = parseReviewPaths(parts.slice(1).join(" "));
				if (paths.length === 0) return { target: null, extraInstruction };
				return { target: { type: "folder", paths }, extraInstruction };
			}

			case "pr": {
				const ref = parts[1];
				if (!ref) return { target: null, extraInstruction };
				return { target: { type: "pr", ref }, extraInstruction };
			}

			default:
				return { target: null, extraInstruction };
		}
	}

	/**
	 * Materialize a PR locally and return a ReviewTarget (or null on failure)
	 */
	async function handlePrCheckout(ctx: ExtensionContext, ref: string): Promise<ReviewTarget | null> {
		// First check for pending changes
		if (await hasPendingChanges(pi)) {
			ctx.ui.notify("Cannot materialize PR: you have local jj changes. Please snapshot or discard them first.", "error");
			return null;
		}

		const prNumber = parsePrReference(ref);
		if (!prNumber) {
			ctx.ui.notify("Invalid PR reference. Enter a number or GitHub PR URL.", "error");
			return null;
		}

		// Get PR info
		ctx.ui.notify(`Fetching PR #${prNumber} info...`, "info");
		const prInfo = await getPrInfo(pi, prNumber);

		if (!prInfo) {
			ctx.ui.notify(`Could not find PR #${prNumber}. Make sure gh is authenticated and the PR exists.`, "error");
			return null;
		}

		// Materialize the PR locally with jj
		ctx.ui.notify(`Materializing PR #${prNumber} with jj...`, "info");
		const materializeResult = await materializePr(pi, prNumber, prInfo);

		if (!materializeResult.success) {
			ctx.ui.notify(`Failed to materialize PR: ${materializeResult.error}`, "error");
			return null;
		}

		ctx.ui.notify(`Materialized PR #${prNumber} (${prInfo.headBookmark}@${materializeResult.remote ?? "origin"})`, "info");

		const baseBookmarkRef = await resolveBookmarkRef(pi, prInfo.baseBookmark);

		return {
			type: "pullRequest",
			prNumber,
			baseBookmark: prInfo.baseBookmark,
			baseRemote: baseBookmarkRef?.remote,
			title: prInfo.title,
		};
	}

	function isLoopCompatibleTarget(target: ReviewTarget): boolean {
		if (target.type !== "change") {
			return true;
		}

		return false;
	}

	async function runLoopFixingReview(
		ctx: ExtensionCommandContext,
		target: ReviewTarget,
		extraInstruction?: string,
	): Promise<void> {
		if (reviewLoopInProgress) {
			ctx.ui.notify("Loop fixing review is already running.", "warning");
			return;
		}

		reviewLoopInProgress = true;
		setReviewWidget(ctx, Boolean(reviewOriginId));
		try {
			ctx.ui.notify(
				"Loop fixing enabled: using Empty branch mode and cycling until no blocking findings remain.",
				"info",
			);

			for (let pass = 1; pass <= REVIEW_LOOP_MAX_ITERATIONS; pass++) {
				const reviewBaselineAssistantId = getLastAssistantSnapshot(ctx)?.id;
				const started = await executeReview(ctx, target, true, {
					includeLocalChanges: true,
					extraInstruction,
				});
				if (!started) {
					ctx.ui.notify("Loop fixing stopped before starting the review pass.", "warning");
					return;
				}

				const reviewTurnStarted = await waitForLoopTurnToStart(ctx, reviewBaselineAssistantId);
				if (!reviewTurnStarted) {
					ctx.ui.notify("Loop fixing stopped: review pass did not start in time.", "error");
					return;
				}

				await ctx.waitForIdle();

				const reviewSnapshot = getLastAssistantSnapshot(ctx);
				if (!reviewSnapshot || reviewSnapshot.id === reviewBaselineAssistantId) {
					ctx.ui.notify("Loop fixing stopped: could not read the review result.", "warning");
					return;
				}

				if (reviewSnapshot.stopReason === "aborted") {
					ctx.ui.notify("Loop fixing stopped: review was aborted.", "warning");
					return;
				}

				if (reviewSnapshot.stopReason === "error") {
					ctx.ui.notify("Loop fixing stopped: review failed with an error.", "error");
					return;
				}

				if (reviewSnapshot.stopReason === "length") {
					ctx.ui.notify("Loop fixing stopped: review output was truncated (stopReason=length).", "warning");
					return;
				}

				if (!hasBlockingReviewFindings(reviewSnapshot.text)) {
					const finalized = await executeEndReviewAction(ctx, "returnAndSummarize", {
						showSummaryLoader: true,
						notifySuccess: false,
					});
					if (finalized !== "ok") {
						return;
					}

					ctx.ui.notify("Loop fixing complete: no blocking findings remain.", "info");
					return;
				}

				ctx.ui.notify(`Loop fixing pass ${pass}: found blocking findings, returning to fix them...`, "info");

				const fixBaselineAssistantId = getLastAssistantSnapshot(ctx)?.id;
				const sentFixPrompt = await executeEndReviewAction(ctx, "returnAndFix", {
					showSummaryLoader: true,
					notifySuccess: false,
				});
				if (sentFixPrompt !== "ok") {
					return;
				}

				const fixTurnStarted = await waitForLoopTurnToStart(ctx, fixBaselineAssistantId);
				if (!fixTurnStarted) {
					ctx.ui.notify("Loop fixing stopped: fix pass did not start in time.", "error");
					return;
				}

				await ctx.waitForIdle();

				const fixSnapshot = getLastAssistantSnapshot(ctx);
				if (!fixSnapshot || fixSnapshot.id === fixBaselineAssistantId) {
					ctx.ui.notify("Loop fixing stopped: could not read the fix pass result.", "warning");
					return;
				}
				if (fixSnapshot.stopReason === "aborted") {
					ctx.ui.notify("Loop fixing stopped: fix pass was aborted.", "warning");
					return;
				}
				if (fixSnapshot.stopReason === "error") {
					ctx.ui.notify("Loop fixing stopped: fix pass failed with an error.", "error");
					return;
				}
				if (fixSnapshot.stopReason === "length") {
					ctx.ui.notify("Loop fixing stopped: fix pass output was truncated (stopReason=length).", "warning");
					return;
				}
			}

			ctx.ui.notify(
				`Loop fixing stopped after ${REVIEW_LOOP_MAX_ITERATIONS} passes (safety limit reached).`,
				"warning",
			);
		} finally {
			reviewLoopInProgress = false;
			setReviewWidget(ctx, Boolean(reviewOriginId));
		}
	}

	// Register the /review command
	pi.registerCommand("review", {
		description: "Review code changes (PR, working copy, bookmark, change, or folder)",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("Review requires interactive mode", "error");
				return;
			}

			if (reviewLoopInProgress) {
				ctx.ui.notify("Loop fixing review is already running.", "warning");
				return;
			}

			// Check if we're already in a review
			if (reviewOriginId) {
				ctx.ui.notify("Already in a review. Use /end-review to finish first.", "warning");
				return;
			}

			// Check if we're in a jj repository
			const { code } = await pi.exec("jj", ["root"]);
			if (code !== 0) {
				ctx.ui.notify("Not a jj repository", "error");
				return;
			}

			// Try to parse direct arguments
			let target: ReviewTarget | null = null;
			let fromSelector = false;
			let extraInstruction: string | undefined;
			const parsed = parseArgs(args);
			if (parsed.error) {
				ctx.ui.notify(parsed.error, "error");
				return;
			}
			extraInstruction = parsed.extraInstruction?.trim() || undefined;

			if (parsed.target) {
				if (parsed.target.type === "pr") {
					// Materialize the PR locally (async operation)
					target = await handlePrCheckout(ctx, parsed.target.ref);
					if (!target) {
						ctx.ui.notify("PR review failed. Returning to review menu.", "warning");
					}
				} else {
					target = parsed.target;
				}
			}

			// If no args or invalid args, show selector
			if (!target) {
				fromSelector = true;
			}

			while (true) {
				if (!target && fromSelector) {
					target = await showReviewSelector(ctx);
				}

				if (!target) {
					ctx.ui.notify("Review cancelled", "info");
					return;
				}

				if (reviewLoopFixingEnabled && !isLoopCompatibleTarget(target)) {
					ctx.ui.notify("Loop mode does not work with change review.", "error");
					if (fromSelector) {
						target = null;
						continue;
					}
					return;
				}

				if (reviewLoopFixingEnabled) {
					await runLoopFixingReview(ctx, target, extraInstruction);
					return;
				}

				// Determine if we should use fresh session mode
				// Check if this is a new session (no messages yet)
				const entries = ctx.sessionManager.getEntries();
				const messageCount = entries.filter((e) => e.type === "message").length;

				// In an empty session, default to fresh review mode so /end-review works consistently.
				let useFreshSession = messageCount === 0;

				if (messageCount > 0) {
					// Existing session - ask user which mode they want
					const choice = await ctx.ui.select("Start review in:", ["Empty branch", "Current session"]);

					if (choice === undefined) {
						if (fromSelector) {
							target = null;
							continue;
						}
						ctx.ui.notify("Review cancelled", "info");
						return;
					}

					useFreshSession = choice === "Empty branch";
				}

				await executeReview(ctx, target, useFreshSession, { extraInstruction });
				return;
			}
		},
	});

	// Custom prompt for review summaries - focuses on preserving actionable findings
	const REVIEW_SUMMARY_PROMPT = `We are leaving a code-review branch and returning to the main coding branch.
Create a structured handoff that can be used immediately to implement fixes.

You MUST summarize the review that happened in this branch so findings can be acted on.
Do not omit findings: include every actionable issue that was identified.

Required sections (in order):

## Review Scope
- What was reviewed (files/paths, changes, and scope)

## Verdict
- "correct" or "needs attention"

## Findings
For EACH finding, include:
- Priority tag ([P0]..[P3]) and short title
- File location (\`path/to/file.ext:line\`)
- Why it matters (brief)
- What should change (brief, actionable)

## Fix Queue
1. Ordered implementation checklist (highest priority first)

## Constraints & Preferences
- Any constraints or preferences mentioned during review
- Or "(none)"

## Human Reviewer Callouts (Non-Blocking)
Include only applicable callouts (no yes/no lines):
- **This change adds a database migration:** <files/details>
- **This change introduces a new dependency:** <package(s)/details>
- **This change changes a dependency (or the lockfile):** <files/package(s)/details>
- **This change modifies auth/permission behavior:** <what changed and where>
- **This change introduces backwards-incompatible public schema/API/contract changes:** <what changed and where>
- **This change includes irreversible or destructive operations:** <operation and scope>

If none apply, write "- (none)".

These are informational callouts for humans and are not fix items by themselves.

Preserve exact file paths, function names, and error messages where available.`;

	const REVIEW_FIX_FINDINGS_PROMPT = `Use the latest review summary in this session and implement the review findings now.

Instructions:
1. Treat the summary's Findings/Fix Queue as a checklist.
2. Fix in priority order: P0, P1, then P2 (include P3 if quick and safe).
3. If a finding is invalid/already fixed/not possible right now, briefly explain why and continue.
4. Treat "Human Reviewer Callouts (Non-Blocking)" as informational only; do not convert them into fix tasks unless there is a separate explicit finding.
5. Follow fail-fast error handling: do not add local catch/fallback recovery unless this scope is an explicit boundary that can safely translate the failure.
6. If you add or keep a \`try/catch\`, explain the expected failure mode and either rethrow with context or return a boundary-safe error response.
7. JSON parsing/decoding should fail loudly by default; avoid silent fallback parsing.
8. Run relevant tests/checks for touched code where practical.
9. End with: fixed items, deferred/skipped items (with reasons), and verification results.`;

	type EndReviewAction = "returnOnly" | "returnAndFix" | "returnAndSummarize";
	type EndReviewActionResult = "ok" | "cancelled" | "error";
	type EndReviewActionOptions = {
		showSummaryLoader?: boolean;
		notifySuccess?: boolean;
	};

	function getActiveReviewOrigin(ctx: ExtensionContext): string | undefined {
		if (reviewOriginId) {
			return reviewOriginId;
		}

		const state = getReviewState(ctx);
		if (state?.active && state.originId) {
			reviewOriginId = state.originId;
			return reviewOriginId;
		}

		if (state?.active) {
			setReviewWidget(ctx, false);
			pi.appendEntry(REVIEW_STATE_TYPE, { active: false });
			ctx.ui.notify("Review state was missing origin info; cleared review status.", "warning");
		}

		return undefined;
	}

	function clearReviewState(ctx: ExtensionContext) {
		setReviewWidget(ctx, false);
		reviewOriginId = undefined;
		pi.appendEntry(REVIEW_STATE_TYPE, { active: false });
	}

	async function navigateWithSummary(
		ctx: ExtensionCommandContext,
		originId: string,
		showLoader: boolean,
	): Promise<{ cancelled: boolean; error?: string } | null> {
		if (showLoader && ctx.hasUI) {
			return ctx.ui.custom<{ cancelled: boolean; error?: string } | null>((tui, theme, _kb, done) => {
				const loader = new BorderedLoader(tui, theme, "Returning and summarizing review branch...");
				loader.onAbort = () => done(null);

				ctx.navigateTree(originId, {
					summarize: true,
					customInstructions: REVIEW_SUMMARY_PROMPT,
					replaceInstructions: true,
				})
					.then(done)
					.catch((err) => done({ cancelled: false, error: err instanceof Error ? err.message : String(err) }));

				return loader;
			});
		}

		try {
			return await ctx.navigateTree(originId, {
				summarize: true,
				customInstructions: REVIEW_SUMMARY_PROMPT,
				replaceInstructions: true,
			});
		} catch (error) {
			return { cancelled: false, error: error instanceof Error ? error.message : String(error) };
		}
	}

	async function executeEndReviewAction(
		ctx: ExtensionCommandContext,
		action: EndReviewAction,
		options: EndReviewActionOptions = {},
	): Promise<EndReviewActionResult> {
		const originId = getActiveReviewOrigin(ctx);
		if (!originId) {
			if (!getReviewState(ctx)?.active) {
				ctx.ui.notify("Not in a review branch (use /review first, or review was started in current session mode)", "info");
			}
			return "error";
		}

		const notifySuccess = options.notifySuccess ?? true;

		if (action === "returnOnly") {
			try {
				const result = await ctx.navigateTree(originId, { summarize: false });
				if (result.cancelled) {
					ctx.ui.notify("Navigation cancelled. Use /end-review to try again.", "info");
					return "cancelled";
				}
			} catch (error) {
				ctx.ui.notify(`Failed to return: ${error instanceof Error ? error.message : String(error)}`, "error");
				return "error";
			}

			clearReviewState(ctx);
			if (notifySuccess) {
				ctx.ui.notify("Review complete! Returned to original position.", "info");
			}
			return "ok";
		}

		const summaryResult = await navigateWithSummary(ctx, originId, options.showSummaryLoader ?? false);
		if (summaryResult === null) {
			ctx.ui.notify("Summarization cancelled. Use /end-review to try again.", "info");
			return "cancelled";
		}

		if (summaryResult.error) {
			ctx.ui.notify(`Summarization failed: ${summaryResult.error}`, "error");
			return "error";
		}

		if (summaryResult.cancelled) {
			ctx.ui.notify("Navigation cancelled. Use /end-review to try again.", "info");
			return "cancelled";
		}

		clearReviewState(ctx);

		if (action === "returnAndSummarize") {
			if (!ctx.ui.getEditorText().trim()) {
				ctx.ui.setEditorText("Act on the review findings");
			}
			if (notifySuccess) {
				ctx.ui.notify("Review complete! Returned and summarized.", "info");
			}
			return "ok";
		}

		pi.sendUserMessage(REVIEW_FIX_FINDINGS_PROMPT, { deliverAs: "followUp" });
		if (notifySuccess) {
			ctx.ui.notify("Review complete! Returned and queued a follow-up to fix findings.", "info");
		}
		return "ok";
	}

	async function runEndReview(ctx: ExtensionCommandContext): Promise<void> {
		if (!ctx.hasUI) {
			ctx.ui.notify("End-review requires interactive mode", "error");
			return;
		}

		if (reviewLoopInProgress) {
			ctx.ui.notify("Loop fixing review is running. Wait for it to finish.", "info");
			return;
		}

		if (endReviewInProgress) {
			ctx.ui.notify("/end-review is already running", "info");
			return;
		}

		endReviewInProgress = true;
		try {
			const choice = await ctx.ui.select("Finish review:", [
				"Return only",
				"Return and fix findings",
				"Return and summarize",
			]);

			if (choice === undefined) {
				ctx.ui.notify("Cancelled. Use /end-review to try again.", "info");
				return;
			}

			const action: EndReviewAction =
				choice === "Return and fix findings"
					? "returnAndFix"
					: choice === "Return and summarize"
						? "returnAndSummarize"
						: "returnOnly";

			await executeEndReviewAction(ctx, action, {
				showSummaryLoader: true,
				notifySuccess: true,
			});
		} finally {
			endReviewInProgress = false;
		}
	}

	// Register the /end-review command
	pi.registerCommand("end-review", {
		description: "Complete review and return to original position",
		handler: async (_args, ctx) => {
			await runEndReview(ctx);
		},
	});
}
