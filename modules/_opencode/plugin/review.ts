import type {
	TuiPlugin,
	TuiPluginModule,
	TuiDialogSelectOption,
} from "@opencode-ai/plugin/tui"
import { promises as fs } from "node:fs"
import path from "node:path"

type BookmarkRef = { name: string; remote?: string }
type Change = { changeId: string; title: string }

type ReviewTarget =
	| { type: "workingCopy" }
	| { type: "baseBookmark"; bookmark: string; remote?: string }
	| { type: "change"; changeId: string; title?: string }
	| {
			type: "pullRequest"
			prNumber: number
			baseBookmark: string
			baseRemote?: string
			title: string
		  }
	| { type: "folder"; paths: string[] }

type ReviewSelectorValue = ReviewTarget["type"] | "toggleCustomInstructions"

const CUSTOM_INSTRUCTIONS_KEY = "review.customInstructions"

const WORKING_COPY_PROMPT =
	"Review the current working-copy changes (including new files) and provide prioritized findings."

const LOCAL_CHANGES_REVIEW_INSTRUCTIONS =
	"Also include local working-copy changes (including new files) on top of this bookmark. Use `jj status`, `jj diff --summary`, and `jj diff` so local fixes are part of this review cycle."

const BASE_BOOKMARK_PROMPT_WITH_MERGE_BASE =
	"Review the code changes against the base bookmark '{baseBookmark}'. The merge-base change for this comparison is {mergeBaseChangeId}. Run `jj diff --from {mergeBaseChangeId} --to @` to inspect the changes relative to {baseBookmark}. Provide prioritized, actionable findings."

const BASE_BOOKMARK_PROMPT_FALLBACK =
	"Review the code changes against the base bookmark '{bookmark}'. Start by finding the merge-base revision between the working copy and {bookmark}, then run `jj diff --from <merge-base> --to @` to see what changes would land on the {bookmark} bookmark. Provide prioritized, actionable findings."

const CHANGE_PROMPT_WITH_TITLE =
	'Review the code changes introduced by change {changeId} ("{title}"). Provide prioritized, actionable findings.'

const CHANGE_PROMPT =
	"Review the code changes introduced by change {changeId}. Provide prioritized, actionable findings."

const PULL_REQUEST_PROMPT =
	'Review pull request #{prNumber} ("{title}") against the base bookmark \'{baseBookmark}\'. The merge-base change for this comparison is {mergeBaseChangeId}. Run `jj diff --from {mergeBaseChangeId} --to @` to inspect the changes that would be merged. Provide prioritized, actionable findings.'

const PULL_REQUEST_PROMPT_FALLBACK =
	'Review pull request #{prNumber} ("{title}") against the base bookmark \'{baseBookmark}\'. Start by finding the merge-base revision between the working copy and {baseBookmark}, then run `jj diff --from <merge-base> --to @` to see the changes that would be merged. Provide prioritized, actionable findings.'

const FOLDER_REVIEW_PROMPT =
	"Review the code in the following paths: {paths}. This is a snapshot review (not a diff). Read the files directly in these paths and provide prioritized, actionable findings."

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

Output all findings the author would fix if they knew about them. If there are no qualifying findings, explicitly state the code looks good. Don't stop at the first finding - list every qualifying issue. Then append the required non-blocking callouts section.`

function bookmarkLabel(b: BookmarkRef): string {
	return b.remote ? `${b.name}@${b.remote}` : b.name
}

function bookmarkRevset(b: BookmarkRef): string {
	const q = JSON.stringify(b.name)
	if (b.remote) {
		return `remote_bookmarks(exact:${q}, exact:${JSON.stringify(b.remote)})`
	}
	return `bookmarks(exact:${q})`
}

function parseBookmarks(stdout: string): BookmarkRef[] {
	const seen = new Set<string>()
	return stdout
		.trim()
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean)
		.map((line) => {
			const [name, remote = ""] = line.split("\t")
			return {
				name: name.trim(),
				remote: remote.trim() || undefined,
			}
		})
		.filter((b) => b.name && b.remote !== "git")
		.filter((b) => {
			const key = `${b.name}@${b.remote ?? ""}`
			if (seen.has(key)) return false
			seen.add(key)
			return true
		})
}

function parseChanges(stdout: string): Change[] {
	return stdout
		.trim()
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean)
		.map((line) => {
			const [changeId, ...rest] = line.split("\t")
			return { changeId, title: rest.join(" ") }
		})
}

function parsePrRef(ref: string): number | null {
	const trimmed = ref.trim()
	const num = parseInt(trimmed, 10)
	if (!isNaN(num) && num > 0) return num
	const urlMatch = trimmed.match(/github\.com\/[^/]+\/[^/]+\/pull\/(\d+)/)
	if (urlMatch) return parseInt(urlMatch[1], 10)
	return null
}

function normalizeRemoteUrl(value: string): string {
	return value
		.trim()
		.replace(/^git@github\.com:/, "https://github.com/")
		.replace(/^ssh:\/\/git@github\.com\//, "https://github.com/")
		.replace(/\.git$/, "")
		.toLowerCase()
}

function sanitizeRemoteName(value: string): string {
	return (
		value.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") ||
		"gh-pr"
	)
}

const plugin: TuiPlugin = async (api) => {
	const cwd = api.state.path.directory
	let reviewCustomInstructions = normalizeCustomInstructions(
		api.kv.get<string | undefined>(CUSTOM_INSTRUCTIONS_KEY, undefined),
	)

	function setReviewCustomInstructions(value?: string): void {
		reviewCustomInstructions = normalizeCustomInstructions(value)
		api.kv.set(CUSTOM_INSTRUCTIONS_KEY, reviewCustomInstructions)
	}

	// -- shell helpers -------------------------------------------------------

	async function exec(
		cmd: string,
		args: string[],
	): Promise<{ stdout: string; exitCode: number; stderr: string }> {
		const proc = Bun.spawn([cmd, ...args], {
			cwd,
			stdout: "pipe",
			stderr: "pipe",
		})
		const [stdout, stderr] = await Promise.all([
			new Response(proc.stdout).text(),
			new Response(proc.stderr).text(),
		])
		const exitCode = await proc.exited
		return { stdout, exitCode, stderr }
	}

	function sleep(ms: number): Promise<void> {
		return new Promise((resolve) => setTimeout(resolve, ms))
	}

	async function jj(
		...args: string[]
	): Promise<{ stdout: string; ok: boolean }> {
		const r = await exec("jj", args)
		return { stdout: r.stdout, ok: r.exitCode === 0 }
	}

	async function gh(
		...args: string[]
	): Promise<{ stdout: string; ok: boolean; stderr: string }> {
		const r = await exec("gh", args)
		return { stdout: r.stdout, ok: r.exitCode === 0, stderr: r.stderr }
	}

	// -- jj helpers ----------------------------------------------------------

	async function isJjRepo(): Promise<boolean> {
		return (await jj("root")).ok
	}

	async function hasWorkingCopyChanges(): Promise<boolean> {
		const r = await jj("diff", "--summary")
		return r.ok && r.stdout.trim().length > 0
	}

	async function getBookmarks(): Promise<BookmarkRef[]> {
		const r = await jj(
			"bookmark",
			"list",
			"--all-remotes",
			"-T",
			'name ++ "\\t" ++ remote ++ "\\n"',
		)
		if (!r.ok) return []
		return parseBookmarks(r.stdout)
	}

	async function getCurrentBookmarks(): Promise<BookmarkRef[]> {
		const headRevset = (await hasWorkingCopyChanges()) ? "@" : "@-"
		const r = await jj(
			"bookmark",
			"list",
			"--all-remotes",
			"-r",
			headRevset,
			"-T",
			'name ++ "\\t" ++ remote ++ "\\n"',
		)
		if (!r.ok) return []
		return parseBookmarks(r.stdout)
	}

	async function getDefaultBookmark(): Promise<BookmarkRef | null> {
		const trunkR = await jj(
			"bookmark",
			"list",
			"--all-remotes",
			"-r",
			"trunk()",
			"-T",
			'name ++ "\\t" ++ remote ++ "\\n"',
		)
		if (trunkR.ok) {
			const bookmarks = parseBookmarks(trunkR.stdout)
			if (bookmarks.length > 0) return bookmarks[0]
		}
		const all = await getBookmarks()
		return (
			all.find((b) => !b.remote && b.name === "main") ??
			all.find((b) => !b.remote && b.name === "master") ??
			all[0] ??
			null
		)
	}

	async function getRecentChanges(limit = 20): Promise<Change[]> {
		const r = await jj(
			"log",
			"-n",
			String(limit),
			"--no-graph",
			"-T",
			'change_id.shortest(8) ++ "\\t" ++ description.first_line() ++ "\\n"',
		)
		if (!r.ok) return []
		return parseChanges(r.stdout)
	}

	async function getMergeBase(
		bookmark: string,
		remote?: string,
	): Promise<string | null> {
		const ref = await resolveBookmarkRef(bookmark, remote)
		if (!ref) return null
		const r = await jj(
			"log",
			"-r",
			`heads(::@ & ::${bookmarkRevset(ref)})`,
			"--no-graph",
			"-T",
			'change_id.shortest(8) ++ "\\n"',
		)
		if (!r.ok) return null
		const lines = r.stdout
			.trim()
			.split("\n")
			.filter((l) => l.trim())
		return lines.length === 1 ? lines[0].trim() : null
	}

	// -- PR materialization --------------------------------------------------

	async function materializePr(prNumber: number): Promise<
		| {
				ok: true
				title: string
				baseBookmark: string
				baseRemote?: string
				headBookmark: string
				remote: string
				savedChangeId: string
		  }
		| { ok: false; error: string }
	> {
		if (await hasWorkingCopyChanges()) {
			return {
				ok: false,
				error: "You have local jj changes. Snapshot or discard them first.",
			}
		}

		const savedR = await jj(
			"log",
			"-r",
			"@",
			"--no-graph",
			"-T",
			"change_id.shortest(8)",
		)
		const savedChangeId = savedR.stdout.trim()

		const prR = await gh(
			"pr",
			"view",
			String(prNumber),
			"--json",
			"baseRefName,title,headRefName,isCrossRepository,headRepository,headRepositoryOwner",
		)
		if (!prR.ok) {
			return {
				ok: false,
				error: `Could not find PR #${prNumber}. Check gh auth and that the PR exists.`,
			}
		}

		let prInfo: {
			baseRefName: string
			title: string
			headRefName: string
			isCrossRepository: boolean
			headRepository?: { name: string; url: string }
			headRepositoryOwner?: { login: string }
		}
		try {
			prInfo = JSON.parse(prR.stdout)
		} catch {
			return { ok: false, error: "Failed to parse PR info" }
		}

		const remotesR = await jj("git", "remote", "list")
		const remotes = remotesR.stdout
			.trim()
			.split("\n")
			.filter(Boolean)
			.map((line) => {
				const [name, ...urlParts] = line.split(/\s+/)
				return { name, url: urlParts.join(" ") }
			})
			.filter((r) => r.name && r.url)

		const defaultRemote =
			remotes.find((r) => r.name === "origin") ?? remotes[0]
		if (!defaultRemote) {
			return { ok: false, error: "No jj remotes configured" }
		}

		let remoteName = defaultRemote.name
		let addedTempRemote = false

		if (prInfo.isCrossRepository) {
			const repoSlug =
				prInfo.headRepositoryOwner?.login && prInfo.headRepository?.name
					? `${prInfo.headRepositoryOwner.login}/${prInfo.headRepository.name}`.toLowerCase()
					: undefined
			const forkUrl = prInfo.headRepository?.url

			const existingRemote = remotes.find((r) => {
				if (
					forkUrl &&
					normalizeRemoteUrl(r.url) === normalizeRemoteUrl(forkUrl)
				)
					return true
				return repoSlug
					? normalizeRemoteUrl(r.url).includes(
							`github.com/${repoSlug}`,
						)
					: false
			})

			if (existingRemote) {
				remoteName = existingRemote.name
			} else if (forkUrl) {
				const baseName = sanitizeRemoteName(
					`gh-pr-${prInfo.headRepositoryOwner?.login ?? "remote"}-${prInfo.headRepository?.name ?? prNumber}`,
				)
				const names = new Set(remotes.map((r) => r.name))
				remoteName = baseName
				let suffix = 2
				while (names.has(remoteName)) {
					remoteName = `${baseName}-${suffix++}`
				}
				const addR = await jj(
					"git",
					"remote",
					"add",
					remoteName,
					forkUrl,
				)
				if (!addR.ok) return { ok: false, error: "Failed to add PR remote" }
				addedTempRemote = true
			} else {
				return { ok: false, error: "PR fork URL is unavailable" }
			}
		}

		const fetchR = await jj(
			"git",
			"fetch",
			"--remote",
			remoteName,
			"--branch",
			prInfo.headRefName,
		)
		if (!fetchR.ok) {
			if (addedTempRemote)
				await jj("git", "remote", "remove", remoteName)
			return { ok: false, error: "Failed to fetch PR branch" }
		}

		const revset = `remote_bookmarks(exact:${JSON.stringify(prInfo.headRefName)}, exact:${JSON.stringify(remoteName)})`
		const newR = await jj("new", revset)
		if (!newR.ok) {
			if (addedTempRemote)
				await jj("git", "remote", "remove", remoteName)
			return { ok: false, error: "Failed to create change on PR branch" }
		}

		if (addedTempRemote) await jj("git", "remote", "remove", remoteName)

		// Resolve base bookmark remote
		const baseRef = await resolveBookmarkRef(prInfo.baseRefName)

		return {
			ok: true,
			title: prInfo.title,
			baseBookmark: prInfo.baseRefName,
			baseRemote: baseRef?.remote,
			headBookmark: prInfo.headRefName,
			remote: remoteName,
			savedChangeId,
		}
	}

	function normalizeCustomInstructions(
		value: string | undefined,
	): string | undefined {
		const normalized = value?.trim()
		return normalized ? normalized : undefined
	}

	function parseNonEmptyLines(stdout: string): string[] {
		return stdout
			.trim()
			.split("\n")
			.map((line) => line.trim())
			.filter(Boolean)
	}

	function bookmarkRefsEqual(left: BookmarkRef, right: BookmarkRef): boolean {
		return left.name === right.name && left.remote === right.remote
	}

	function parseBookmarkReference(value: string): BookmarkRef {
		const trimmed = value.trim()
		const separatorIndex = trimmed.lastIndexOf("@")
		if (separatorIndex <= 0 || separatorIndex === trimmed.length - 1) {
			return { name: trimmed }
		}

		return {
			name: trimmed.slice(0, separatorIndex),
			remote: trimmed.slice(separatorIndex + 1),
		}
	}

	function dedupeBookmarkRefs(bookmarks: BookmarkRef[]): BookmarkRef[] {
		const seen = new Set<string>()
		const result: BookmarkRef[] = []

		for (const bookmark of bookmarks) {
			const key = `${bookmark.name}@${bookmark.remote ?? ""}`
			if (seen.has(key)) continue
			seen.add(key)
			result.push(bookmark)
		}

		return result
	}

	async function getBookmarkRefs(options?: {
		revset?: string
		includeRemotes?: boolean
	}): Promise<BookmarkRef[]> {
		const args = ["bookmark", "list"]
		if (options?.includeRemotes) args.push("--all-remotes")
		if (options?.revset) args.push("-r", options.revset)
		args.push("-T", 'name ++ "\\t" ++ remote ++ "\\n"')

		const r = await jj(...args)
		if (!r.ok) return []
		return dedupeBookmarkRefs(parseBookmarks(r.stdout))
	}

	async function getSingleRevisionId(revset: string): Promise<string | null> {
		const r = await jj(
			"log",
			"-r",
			revset,
			"--no-graph",
			"-T",
			'commit_id ++ "\\n"',
		)
		if (!r.ok) return null

		const revisions = parseNonEmptyLines(r.stdout)
		return revisions.length === 1 ? revisions[0] : null
	}

	async function getSingleChangeId(revset: string): Promise<string | null> {
		const r = await jj(
			"log",
			"-r",
			revset,
			"--no-graph",
			"-T",
			'change_id.shortest(8) ++ "\\n"',
		)
		if (!r.ok) return null

		const revisions = parseNonEmptyLines(r.stdout)
		return revisions.length === 1 ? revisions[0] : null
	}

	async function getJjRemotes(): Promise<Array<{ name: string; url: string }>> {
		const r = await jj("git", "remote", "list")
		if (!r.ok) return []

		return parseNonEmptyLines(r.stdout)
			.map((line) => {
				const [name, ...urlParts] = line.split(/\s+/)
				return { name, url: urlParts.join(" ") }
			})
			.filter((remote) => remote.name && remote.url)
	}

	async function getDefaultRemoteName(): Promise<string | null> {
		const remotes = await getJjRemotes()
		if (remotes.length === 0) return null
		return remotes.find((remote) => remote.name === "origin")?.name ?? remotes[0].name
	}

	function preferBookmarkRef(
		bookmarks: BookmarkRef[],
		preferredRemote?: string | null,
	): BookmarkRef | null {
		if (bookmarks.length === 0) return null
		return (
			bookmarks.find((bookmark) => !bookmark.remote) ??
			(preferredRemote
				? bookmarks.find((bookmark) => bookmark.remote === preferredRemote)
				: undefined) ??
			bookmarks[0]
		)
	}

	async function resolveBookmarkRef(
		bookmark: string,
		remote?: string,
	): Promise<BookmarkRef | null> {
		if (remote) return { name: bookmark, remote }

		const localBookmark = (await getBookmarkRefs()).find(
			(entry) => entry.name === bookmark,
		)
		if (localBookmark) return localBookmark

		const matchingRemoteBookmarks = (
			await getBookmarkRefs({ includeRemotes: true })
		).filter((entry) => entry.remote && entry.name === bookmark)
		if (matchingRemoteBookmarks.length === 0) return null

		return preferBookmarkRef(
			matchingRemoteBookmarks,
			await getDefaultRemoteName(),
		)
	}

	async function getReviewBookmarks(): Promise<BookmarkRef[]> {
		const localBookmarks = await getBookmarkRefs()
		const localNames = new Set(localBookmarks.map((bookmark) => bookmark.name))
		const defaultRemoteName = await getDefaultRemoteName()
		const remoteOnlyBookmarks = (
			await getBookmarkRefs({ includeRemotes: true })
		)
			.filter((bookmark) => bookmark.remote && !localNames.has(bookmark.name))
			.sort((left, right) => {
				if (left.name !== right.name) return left.name.localeCompare(right.name)
				if (left.remote === defaultRemoteName) return -1
				if (right.remote === defaultRemoteName) return 1
				return (left.remote ?? "").localeCompare(right.remote ?? "")
			})

		return dedupeBookmarkRefs([...localBookmarks, ...remoteOnlyBookmarks])
	}

	async function getReviewHeadRevset(): Promise<string> {
		return (await hasWorkingCopyChanges()) ? "@" : "@-"
	}

	async function getCurrentReviewBookmarks(): Promise<BookmarkRef[]> {
		return getBookmarkRefs({
			revset: await getReviewHeadRevset(),
			includeRemotes: true,
		})
	}

	async function getDefaultBookmarkRef(): Promise<BookmarkRef | null> {
		const defaultRemoteName = await getDefaultRemoteName()
		const trunkBookmarks = await getBookmarkRefs({
			revset: "trunk()",
			includeRemotes: true,
		})
		const trunkBookmark = preferBookmarkRef(trunkBookmarks, defaultRemoteName)
		if (trunkBookmark) return trunkBookmark

		const bookmarks = await getReviewBookmarks()
		const mainBookmark =
			bookmarks.find((bookmark) => !bookmark.remote && bookmark.name === "main") ??
			bookmarks.find((bookmark) => !bookmark.remote && bookmark.name === "master") ??
			bookmarks.find(
				(bookmark) =>
					bookmark.remote === defaultRemoteName && bookmark.name === "main",
			) ??
			bookmarks.find(
				(bookmark) =>
					bookmark.remote === defaultRemoteName && bookmark.name === "master",
			)
		return mainBookmark ?? bookmarks[0] ?? null
	}

	async function loadProjectReviewGuidelines(): Promise<string | null> {
		let currentDir = path.resolve(cwd)

		while (true) {
			const opencodeDir = path.join(currentDir, ".opencode")
			const guidelinesPath = path.join(currentDir, "REVIEW_GUIDELINES.md")

			const opencodeStats = await fs.stat(opencodeDir).catch(() => null)
			if (opencodeStats?.isDirectory()) {
				const guidelineStats = await fs.stat(guidelinesPath).catch(() => null)
				if (!guidelineStats?.isFile()) return null

				try {
					const content = await fs.readFile(guidelinesPath, "utf8")
					const trimmed = content.trim()
					return trimmed ? trimmed : null
				} catch {
					return null
				}
			}

			const parentDir = path.dirname(currentDir)
			if (parentDir === currentDir) return null
			currentDir = parentDir
		}
	}

	// -- prompt building -----------------------------------------------------

	async function buildTargetReviewPrompt(
		target: ReviewTarget,
		options?: { includeLocalChanges?: boolean },
	): Promise<string> {
		const includeLocalChanges = options?.includeLocalChanges === true

		switch (target.type) {
			case "workingCopy":
				return WORKING_COPY_PROMPT

			case "baseBookmark": {
				const bookmark = await resolveBookmarkRef(
					target.bookmark,
					target.remote,
				)
				const bookmarkLabelValue = bookmarkLabel(
					bookmark ?? { name: target.bookmark, remote: target.remote },
				)
				const mergeBase = await getMergeBase(target.bookmark, target.remote)
				const basePrompt = mergeBase
					? BASE_BOOKMARK_PROMPT_WITH_MERGE_BASE
							.replace(/{baseBookmark}/g, bookmarkLabelValue)
							.replace(/{mergeBaseChangeId}/g, mergeBase)
					: BASE_BOOKMARK_PROMPT_FALLBACK.replace(
							/{bookmark}/g,
							bookmarkLabelValue,
						)
				return includeLocalChanges
					? `${basePrompt} ${LOCAL_CHANGES_REVIEW_INSTRUCTIONS}`
					: basePrompt
			}

			case "change":
				return target.title
					? CHANGE_PROMPT_WITH_TITLE.replace(
							"{changeId}",
							target.changeId,
						).replace("{title}", target.title)
					: CHANGE_PROMPT.replace("{changeId}", target.changeId)

			case "pullRequest": {
				const bookmark = await resolveBookmarkRef(
					target.baseBookmark,
					target.baseRemote,
				)
				const baseBookmarkLabel = bookmarkLabel(
					bookmark ?? {
						name: target.baseBookmark,
						remote: target.baseRemote,
					},
				)
				const mergeBase = await getMergeBase(
					target.baseBookmark,
					target.baseRemote,
				)
				const basePrompt = mergeBase
					? PULL_REQUEST_PROMPT.replace(/{prNumber}/g, String(target.prNumber))
							.replace(/{title}/g, target.title)
							.replace(/{baseBookmark}/g, baseBookmarkLabel)
							.replace(/{mergeBaseChangeId}/g, mergeBase)
					: PULL_REQUEST_PROMPT_FALLBACK.replace(
							/{prNumber}/g,
							String(target.prNumber),
						)
							.replace(/{title}/g, target.title)
							.replace(/{baseBookmark}/g, baseBookmarkLabel)
				return includeLocalChanges
					? `${basePrompt} ${LOCAL_CHANGES_REVIEW_INSTRUCTIONS}`
					: basePrompt
			}

			case "folder":
				return FOLDER_REVIEW_PROMPT.replace(
					"{paths}",
					target.paths.join(", "),
				)
		}
	}

	async function buildReviewPrompt(target: ReviewTarget): Promise<string> {
		const prompt = await buildTargetReviewPrompt(target)
		const projectGuidelines = await loadProjectReviewGuidelines()
		const sharedInstructions = normalizeCustomInstructions(
			reviewCustomInstructions,
		)
		let fullPrompt = `${REVIEW_RUBRIC}\n\n---\n\nPlease perform a code review with the following focus:\n\n${prompt}`

		if (sharedInstructions) {
			fullPrompt += `\n\nShared custom review instructions (applies to all reviews):\n\n${sharedInstructions}`
		}

		if (projectGuidelines) {
			fullPrompt += `\n\nThis project has additional instructions for code reviews:\n\n${projectGuidelines}`
		}

		return fullPrompt
	}

	async function getSmartDefault(): Promise<
		"workingCopy" | "baseBookmark" | "change"
	> {
		if (await hasWorkingCopyChanges()) return "workingCopy"

		const defaultBookmark = await getDefaultBookmarkRef()
		if (defaultBookmark) {
			const reviewHeadRevision = await getSingleRevisionId(
				await getReviewHeadRevset(),
			)
			const defaultBookmarkRevision = await getSingleRevisionId(
				bookmarkRevset(defaultBookmark),
			)
			if (
				reviewHeadRevision &&
				defaultBookmarkRevision &&
				reviewHeadRevision !== defaultBookmarkRevision
			) {
				return "baseBookmark"
			}
		}

		return "change"
	}

	function getUserFacingHint(target: ReviewTarget): string {
		switch (target.type) {
			case "workingCopy":
				return "working-copy changes"
			case "baseBookmark":
				return `changes against '${bookmarkLabel({ name: target.bookmark, remote: target.remote })}'`
			case "change":
				return target.title
					? `change ${target.changeId}: ${target.title}`
					: `change ${target.changeId}`
			case "pullRequest": {
				const shortTitle =
					target.title.length > 30
						? `${target.title.slice(0, 27)}...`
						: target.title
				return `PR #${target.prNumber}: ${shortTitle}`
			}
			case "folder": {
				const joined = target.paths.join(", ")
				return joined.length > 40
					? `folders: ${joined.slice(0, 37)}...`
					: `folders: ${joined}`
			}
		}
	}

	// -- review execution ----------------------------------------------------

	async function startReview(target: ReviewTarget): Promise<void> {
		const prompt = await buildReviewPrompt(target)
		const hint = getUserFacingHint(target)
		const cleared = await api.client.tui.clearPrompt()
		const appended = await api.client.tui.appendPrompt({
			text: prompt,
		})
		// `prompt.submit` is ignored unless the prompt input is focused.
		// When this runs from a dialog, focus returns on the next tick.
		await sleep(50)
		const submitted = await api.client.tui.submitPrompt()

		if (!cleared || !appended || !submitted) {
			api.ui.toast({
				message: "Failed to start review prompt automatically",
				variant: "error",
			})
			return
		}

		api.ui.toast({
			message: `Starting review: ${hint}`,
			variant: "info",
		})
	}

	// -- dialogs -------------------------------------------------------------

	async function showReviewSelector(): Promise<void> {
		const smartDefault = await getSmartDefault()
		const options: TuiDialogSelectOption<ReviewSelectorValue>[] = [
			{
				title: "Review working-copy changes",
				value: "workingCopy",
			},
			{
				title: "Review against a base bookmark",
				value: "baseBookmark",
				description: "(local)",
			},
			{
				title: "Review a change",
				value: "change",
			},
			{
				title: "Review a pull request",
				value: "pullRequest",
				description: "(GitHub PR)",
			},
			{
				title: "Review a folder (or more)",
				value: "folder",
				description: "(snapshot, not diff)",
			},
			{
				title: reviewCustomInstructions
					? "Remove custom review instructions"
					: "Add custom review instructions",
				value: "toggleCustomInstructions",
				description: reviewCustomInstructions
					? "(currently set)"
					: "(applies to all review modes)",
			},
		]

		api.ui.dialog.replace(
			() =>
				api.ui.DialogSelect({
					title: "Select a review preset",
					options,
					current: smartDefault,
					onSelect: (option) => {
						api.ui.dialog.clear()
						switch (option.value) {
							case "workingCopy":
								void startReview({ type: "workingCopy" })
								break
							case "baseBookmark":
								void showBookmarkSelector()
								break
							case "change":
								void showChangeSelector()
								break
							case "pullRequest":
								void showPrInput()
								break
							case "folder":
								showFolderInput()
								break
							case "toggleCustomInstructions":
								if (reviewCustomInstructions) {
									setReviewCustomInstructions(undefined)
									api.ui.toast({
										message: "Custom review instructions removed",
										variant: "info",
									})
									void showReviewSelector()
									break
								}
								showCustomInstructionsInput()
								break
						}
					},
				}),
		)
	}

	function showCustomInstructionsInput(): void {
		api.ui.dialog.replace(
			() =>
				api.ui.DialogPrompt({
					title: "Custom review instructions",
					placeholder: "focus on performance regressions",
					value: reviewCustomInstructions,
					onConfirm: (value) => {
						const next = normalizeCustomInstructions(value)
						api.ui.dialog.clear()
						if (!next) {
							api.ui.toast({
								message: "Custom review instructions not changed",
								variant: "info",
							})
							void showReviewSelector()
							return
						}

						setReviewCustomInstructions(next)
						api.ui.toast({
							message: "Custom review instructions saved",
							variant: "success",
						})
						void showReviewSelector()
					},
					onCancel: () => {
						api.ui.dialog.clear()
						void showReviewSelector()
					},
				}),
		)
	}

	async function showBookmarkSelector(): Promise<void> {
		api.ui.toast({ message: "Loading bookmarks...", variant: "info" })

		const bookmarks = await getReviewBookmarks()
		const currentBookmarks = await getCurrentReviewBookmarks()
		const defaultBookmark = await getDefaultBookmarkRef()

		const candidates = bookmarks.filter(
			(bookmark) =>
				!currentBookmarks.some((currentBookmark) =>
					bookmarkRefsEqual(bookmark, currentBookmark),
				),
		)

		if (candidates.length === 0) {
			const currentLabel = currentBookmarks[0]
				? bookmarkLabel(currentBookmarks[0])
				: undefined
			api.ui.toast({
				message: currentLabel
					? `No other bookmarks found (current bookmark: ${currentLabel})`
					: "No bookmarks found",
				variant: "error",
			})
			return
		}

		const sorted = candidates.sort((a, b) => {
			if (defaultBookmark && bookmarkRefsEqual(a, defaultBookmark)) return -1
			if (defaultBookmark && bookmarkRefsEqual(b, defaultBookmark)) return 1
			if (!!a.remote !== !!b.remote) return a.remote ? 1 : -1
			return bookmarkLabel(a).localeCompare(bookmarkLabel(b))
		})

		const options: TuiDialogSelectOption<BookmarkRef>[] = sorted.map(
			(b) => ({
				title: bookmarkLabel(b),
				value: b,
				description:
					defaultBookmark && bookmarkRefsEqual(b, defaultBookmark)
						? "(default)"
						: b.remote
							? `(remote ${b.remote})`
							: undefined,
			}),
		)

		api.ui.dialog.replace(
			() =>
				api.ui.DialogSelect({
					title: "Select base bookmark",
					placeholder: "Filter bookmarks...",
					options,
					onSelect: (option) => {
						api.ui.dialog.clear()
						void startReview({
							type: "baseBookmark",
							bookmark: option.value.name,
							remote: option.value.remote,
						})
					},
				}),
		)
	}

	async function showChangeSelector(): Promise<void> {
		api.ui.toast({ message: "Loading changes...", variant: "info" })

		const changes = await getRecentChanges()
		if (changes.length === 0) {
			api.ui.toast({ message: "No changes found", variant: "error" })
			return
		}

		const options: TuiDialogSelectOption<Change>[] = changes.map((c) => ({
			title: `${c.changeId}  ${c.title}`,
			value: c,
		}))

		api.ui.dialog.replace(
			() =>
				api.ui.DialogSelect({
					title: "Select change to review",
					placeholder: "Filter changes...",
					options,
					onSelect: (option) => {
						api.ui.dialog.clear()
						void startReview({
							type: "change",
							changeId: option.value.changeId,
							title: option.value.title,
						})
					},
				}),
		)
	}

	async function showPrInput(): Promise<void> {
		if (await hasWorkingCopyChanges()) {
			api.ui.toast({
				message:
					"Cannot materialize PR: you have local jj changes. Please snapshot or discard them first.",
				variant: "error",
			})
			return
		}

		api.ui.dialog.replace(
			() =>
				api.ui.DialogPrompt({
					title: "Enter PR number or URL",
					placeholder:
						"123 or https://github.com/owner/repo/pull/123",
					onConfirm: (value) => {
						const prNumber = parsePrRef(value)
						if (!prNumber) {
							api.ui.toast({
								message:
									"Invalid PR reference. Enter a number or GitHub PR URL.",
								variant: "error",
							})
							return
						}
						api.ui.dialog.clear()
						void handlePrReview(prNumber)
					},
				}),
		)
	}

	async function handlePrReview(prNumber: number): Promise<void> {
		api.ui.toast({
			message: `Fetching PR #${prNumber} info...`,
			variant: "info",
		})

		api.ui.toast({
			message: `Materializing PR #${prNumber} with jj...`,
			variant: "info",
			duration: 10000,
		})

		const result = await materializePr(prNumber)
		if (!result.ok) {
			api.ui.toast({ message: result.error, variant: "error" })
			return
		}

		api.ui.toast({
			message: `Materialized PR #${prNumber} (${result.headBookmark}@${result.remote})`,
			variant: "info",
		})

		await startReview({
			type: "pullRequest",
			prNumber,
			baseBookmark: result.baseBookmark,
			baseRemote: result.baseRemote,
			title: result.title,
		})
	}

	function showFolderInput(): void {
		api.ui.dialog.replace(
			() =>
				api.ui.DialogPrompt({
					title: "Enter folders/files to review",
					placeholder: ".",
					onConfirm: (value) => {
						const paths = value
							.split(/\s+/)
							.map((p) => p.trim())
							.filter((p) => p.length > 0)
						if (paths.length === 0) {
							api.ui.toast({
								message: "No paths provided",
								variant: "error",
							})
							return
						}
						api.ui.dialog.clear()
						void startReview({ type: "folder", paths })
					},
				}),
		)
	}

	// -- jj repo check -------------------------------------------------------

	const inJjRepo = await isJjRepo()

	// -- command registration ------------------------------------------------

	api.command.register(() =>
		inJjRepo
			? [
					{
						title: "Review code changes",
						value: "review",
						description:
							"Review code changes (PR, working copy, bookmark, change, or folder)",
						slash: { name: "review", aliases: ["jj-review"] },
						onSelect: () => void showReviewSelector(),
					},
				]
			: [],
	)
}

export default {
	id: "review",
	tui: plugin,
} satisfies TuiPluginModule
