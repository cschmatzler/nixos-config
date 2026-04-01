import type {
	TuiPlugin,
	TuiPluginModule,
	TuiDialogSelectOption,
} from "@opencode-ai/plugin/tui"

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
		const ref: BookmarkRef = { name: bookmark, remote }
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
		const baseBms = await getBookmarks()
		const baseRef = baseBms.find((b) => b.name === prInfo.baseRefName)

		return {
			ok: true,
			title: prInfo.title,
			baseBookmark: prInfo.baseRefName,
			baseRemote: baseRef?.remote,
			savedChangeId,
		}
	}

	// -- prompt building -----------------------------------------------------

	async function buildPrompt(target: ReviewTarget): Promise<string> {
		switch (target.type) {
			case "workingCopy":
				return "Review the current working-copy changes (including new files). Use `jj status`, `jj diff --summary`, and `jj diff` to inspect."

			case "baseBookmark": {
				const label = bookmarkLabel({
					name: target.bookmark,
					remote: target.remote,
				})
				const mergeBase = await getMergeBase(
					target.bookmark,
					target.remote,
				)
				if (mergeBase) {
					return `Review code changes against the base bookmark '${label}'. The merge-base change is ${mergeBase}. Run \`jj diff --from ${mergeBase} --to @\` to inspect the changes. Also check for local working-copy changes with \`jj diff --summary\`.`
				}
				return `Review code changes against the base bookmark '${label}'. Find the merge-base between @ and ${label}, then run \`jj diff --from <merge-base> --to @\`. Also check for local working-copy changes.`
			}

			case "change":
				return target.title
					? `Review the code changes introduced by change ${target.changeId} ("${target.title}"). Use \`jj show ${target.changeId}\` to inspect.`
					: `Review the code changes introduced by change ${target.changeId}. Use \`jj show ${target.changeId}\` to inspect.`

			case "pullRequest": {
				const label = bookmarkLabel({
					name: target.baseBookmark,
					remote: target.baseRemote,
				})
				const mergeBase = await getMergeBase(
					target.baseBookmark,
					target.baseRemote,
				)
				if (mergeBase) {
					return `Review pull request #${target.prNumber} ("${target.title}") against '${label}'. Merge-base is ${mergeBase}. Run \`jj diff --from ${mergeBase} --to @\` to inspect.`
				}
				return `Review pull request #${target.prNumber} ("${target.title}") against '${label}'. Find the merge-base and run \`jj diff --from <merge-base> --to @\`.`
			}

			case "folder":
				return `Review the code in the following paths: ${target.paths.join(", ")}. This is a snapshot review (not a diff). Read the files directly.`
		}
	}

	// -- review execution ----------------------------------------------------

	async function startReview(target: ReviewTarget): Promise<void> {
		const prompt = await buildPrompt(target)
		await api.client.tui.clearPrompt()
		await api.client.tui.appendPrompt({
			text: `@review ${prompt}`,
		})
		await api.client.tui.submitPrompt()
	}

	// -- dialogs -------------------------------------------------------------

	function showReviewSelector(): void {
		const options: TuiDialogSelectOption<string>[] = [
			{
				title: "Working-copy changes",
				value: "workingCopy",
				description: "Review uncommitted changes",
			},
			{
				title: "Against a bookmark",
				value: "baseBookmark",
				description: "PR-style review against a base",
			},
			{
				title: "A specific change",
				value: "change",
				description: "Review a single jj change",
			},
			{
				title: "A pull request",
				value: "pullRequest",
				description: "Materialize and review a GitHub PR",
			},
			{
				title: "A folder (snapshot)",
				value: "folder",
				description: "Review files directly, no diff",
			},
		]

		api.ui.dialog.replace(
			() =>
				api.ui.DialogSelect({
					title: "Review",
					options,
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
						}
					},
				}),
			() => api.ui.dialog.clear(),
		)
	}

	async function showBookmarkSelector(): Promise<void> {
		api.ui.toast({ message: "Loading bookmarks...", variant: "info" })

		const allBookmarks = await getBookmarks()
		const currentBookmarks = await getCurrentBookmarks()
		const defaultBookmark = await getDefaultBookmark()

		const currentKeys = new Set(
			currentBookmarks.map((b) => `${b.name}@${b.remote ?? ""}`),
		)
		const candidates = allBookmarks.filter(
			(b) => !currentKeys.has(`${b.name}@${b.remote ?? ""}`),
		)

		if (candidates.length === 0) {
			api.ui.toast({
				message: "No other bookmarks found",
				variant: "error",
			})
			return
		}

		// Sort: default first, then local before remote
		const defaultKey = defaultBookmark
			? `${defaultBookmark.name}@${defaultBookmark.remote ?? ""}`
			: null
		const sorted = candidates.sort((a, b) => {
			const aKey = `${a.name}@${a.remote ?? ""}`
			const bKey = `${b.name}@${b.remote ?? ""}`
			if (aKey === defaultKey) return -1
			if (bKey === defaultKey) return 1
			if (!!a.remote !== !!b.remote) return a.remote ? 1 : -1
			return bookmarkLabel(a).localeCompare(bookmarkLabel(b))
		})

		const options: TuiDialogSelectOption<BookmarkRef>[] = sorted.map(
			(b) => ({
				title: bookmarkLabel(b),
				value: b,
				description:
					`${b.name}@${b.remote ?? ""}` === defaultKey
						? "(default)"
						: b.remote
							? `remote: ${b.remote}`
							: undefined,
			}),
		)

		api.ui.dialog.replace(
			() =>
				api.ui.DialogSelect({
					title: "Base bookmark",
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
			() => api.ui.dialog.clear(),
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
					title: "Change to review",
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
			() => api.ui.dialog.clear(),
		)
	}

	function showPrInput(): void {
		api.ui.dialog.replace(
			() =>
				api.ui.DialogPrompt({
					title: "PR number or URL",
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
					onCancel: () => api.ui.dialog.clear(),
				}),
			() => api.ui.dialog.clear(),
		)
	}

	async function handlePrReview(prNumber: number): Promise<void> {
		api.ui.toast({
			message: `Materializing PR #${prNumber}...`,
			variant: "info",
			duration: 10000,
		})

		const result = await materializePr(prNumber)
		if (!result.ok) {
			api.ui.toast({ message: result.error, variant: "error" })
			return
		}

		api.ui.toast({
			message: `PR #${prNumber} materialized: ${result.title}`,
			variant: "success",
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
					title: "Paths to review",
					placeholder: "src docs lib/utils.ts",
					onConfirm: (value) => {
						const paths = value
							.split(/\s+/)
							.map((p) => p.trim())
							.filter(Boolean)
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
					onCancel: () => api.ui.dialog.clear(),
				}),
			() => api.ui.dialog.clear(),
		)
	}

	// -- jj repo check -------------------------------------------------------

	const inJjRepo = await isJjRepo()

	// -- command registration ------------------------------------------------

	api.command.register(() =>
		inJjRepo
			? [
					{
						title: "Review code changes (jj)",
						value: "jj-review",
						description:
							"Working-copy, bookmark, change, PR, or folder",
						slash: { name: "jj-review" },
						onSelect: () => showReviewSelector(),
					},
				]
			: [],
	)
}

export default {
	id: "jj-review",
	tui: plugin,
} satisfies TuiPluginModule
