import { type Plugin, tool } from "@opencode-ai/plugin"

function normalizeRemoteUrl(value: string): string {
	return value
		.trim()
		.replace(/^git@github\.com:/, "https://github.com/")
		.replace(/^ssh:\/\/git@github\.com\//, "https://github.com/")
		.replace(/\.git$/, "")
		.toLowerCase()
}

function sanitizeRemoteName(value: string): string {
	const sanitized = value.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "")
	return sanitized || "gh-pr"
}

export const ReviewPlugin: Plugin = async ({ $ }) => {
	return {
		tool: {
			review_materialize_pr: tool({
				description:
					"Materialize a GitHub pull request locally using jj for code review. " +
					"Fetches the PR branch, creates a new jj change on top of it, and returns " +
					"metadata needed for the review. Handles cross-repository (forked) PRs. " +
					"Call this before reviewing a PR to set up the local state.",
				args: {
					prNumber: tool.schema
						.number()
						.describe("The PR number to materialize (e.g. 123)"),
				},
				async execute(args, context) {
					const prNumber = args.prNumber

					// Check for pending working-copy changes
					const statusResult =
						await $`jj diff --summary 2>/dev/null`.nothrow().quiet()
					if (
						statusResult.exitCode === 0 &&
						statusResult.stdout.toString().trim().length > 0
					) {
						return JSON.stringify({
							success: false,
							error:
								"Cannot materialize PR: you have local jj changes. Please snapshot or discard them first.",
						})
					}

					// Save current position for later restoration
					const currentChangeResult =
						await $`jj log -r @ --no-graph -T 'change_id.shortest(8)'`
							.nothrow()
							.quiet()
					const savedChangeId = currentChangeResult.stdout.toString().trim()

					// Get PR info from GitHub CLI
					const prInfoResult =
						await $`gh pr view ${prNumber} --json baseRefName,title,headRefName,isCrossRepository,headRepository,headRepositoryOwner`
							.nothrow()
							.quiet()
					if (prInfoResult.exitCode !== 0) {
						return JSON.stringify({
							success: false,
							error: `Could not find PR #${prNumber}. Make sure gh is authenticated and the PR exists.`,
						})
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
						prInfo = JSON.parse(prInfoResult.stdout.toString())
					} catch {
						return JSON.stringify({
							success: false,
							error: "Failed to parse PR info from gh CLI",
						})
					}

					// Determine the remote to use
					const remotesResult =
						await $`jj git remote list`.nothrow().quiet()
					const remotes = remotesResult.stdout
						.toString()
						.trim()
						.split("\n")
						.filter(Boolean)
						.map((line: string) => {
							const [name, ...urlParts] = line.split(/\s+/)
							return { name, url: urlParts.join(" ") }
						})
						.filter(
							(r: { name: string; url: string }) => r.name && r.url,
						)

					const defaultRemote =
						remotes.find(
							(r: { name: string; url: string }) =>
								r.name === "origin",
						) ?? remotes[0]
					if (!defaultRemote) {
						return JSON.stringify({
							success: false,
							error: "No jj remotes are configured for this repository",
						})
					}

					let remoteName = defaultRemote.name
					let addedTemporaryRemote = false

					if (prInfo.isCrossRepository) {
						const repoSlug =
							prInfo.headRepositoryOwner?.login &&
							prInfo.headRepository?.name
								? `${prInfo.headRepositoryOwner.login}/${prInfo.headRepository.name}`.toLowerCase()
								: undefined
						const forkUrl = prInfo.headRepository?.url

						// Check if we already have a remote for this fork
						const existingRemote = remotes.find(
							(r: { name: string; url: string }) => {
								if (
									forkUrl &&
									normalizeRemoteUrl(r.url) ===
										normalizeRemoteUrl(forkUrl)
								) {
									return true
								}
								return repoSlug
									? normalizeRemoteUrl(r.url).includes(
											`github.com/${repoSlug}`,
										)
									: false
							},
						)

						if (existingRemote) {
							remoteName = existingRemote.name
						} else if (forkUrl) {
							const remoteBaseName = sanitizeRemoteName(
								`gh-pr-${prInfo.headRepositoryOwner?.login ?? "remote"}-${prInfo.headRepository?.name ?? prNumber}`,
							)
							const existingNames = new Set(
								remotes.map(
									(r: { name: string; url: string }) =>
										r.name,
								),
							)
							remoteName = remoteBaseName
							let suffix = 2
							while (existingNames.has(remoteName)) {
								remoteName = `${remoteBaseName}-${suffix}`
								suffix += 1
							}
							const addResult =
								await $`jj git remote add ${remoteName} ${forkUrl}`
									.nothrow()
									.quiet()
							if (addResult.exitCode !== 0) {
								return JSON.stringify({
									success: false,
									error:
										addResult.stderr.toString() ||
										"Failed to add PR remote",
								})
							}
							addedTemporaryRemote = true
						} else {
							return JSON.stringify({
								success: false,
								error: "PR head repository URL is unavailable",
							})
						}
					}

					// Fetch the PR branch
					const fetchResult =
						await $`jj git fetch --remote ${remoteName} --branch ${prInfo.headRefName}`
							.nothrow()
							.quiet()
					if (fetchResult.exitCode !== 0) {
						if (addedTemporaryRemote) {
							await $`jj git remote remove ${remoteName}`
								.nothrow()
								.quiet()
						}
						return JSON.stringify({
							success: false,
							error:
								fetchResult.stderr.toString() ||
								"Failed to fetch PR branch",
						})
					}

					// Create a new change on top of the PR branch
					const bookmarkRevset = `remote_bookmarks(exact:"${prInfo.headRefName}", exact:"${remoteName}")`
					const editResult =
						await $`jj new ${bookmarkRevset}`.nothrow().quiet()
					if (editResult.exitCode !== 0) {
						if (addedTemporaryRemote) {
							await $`jj git remote remove ${remoteName}`
								.nothrow()
								.quiet()
						}
						return JSON.stringify({
							success: false,
							error:
								editResult.stderr.toString() ||
								"Failed to create change on PR branch",
						})
					}

					// Clean up temporary remote
					if (addedTemporaryRemote) {
						await $`jj git remote remove ${remoteName}`
							.nothrow()
							.quiet()
					}

					return JSON.stringify({
						success: true,
						prNumber,
						title: prInfo.title,
						baseBookmark: prInfo.baseRefName,
						headBookmark: prInfo.headRefName,
						remote: remoteName,
						savedChangeId,
					})
				},
			}),
		},
	}
}
