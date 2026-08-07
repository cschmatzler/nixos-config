import {formatSidebarTokens, parsePullRequest, type SidebarTokens} from "./pr-status";

const SOURCE = "gh-pr-workspace";
const TOKEN_NAMES = ["pr", "merge", "ci", "review"] as const;

type CommandSuccess = {
  readonly _tag: "success";
  readonly stdout: string;
  readonly stderr: string;
};

type CommandFailure = {
  readonly _tag: "failure";
  readonly command: string;
  readonly exitCode: number;
  readonly stdout: string;
  readonly stderr: string;
  readonly cause?: unknown;
};

type CommandResult = CommandSuccess | CommandFailure;

type Workspace = {
  readonly id: string;
  readonly fallbackCwd?: string;
};

type PullRequestLookup =
  | { readonly _tag: "found"; readonly tokens: SidebarTokens }
  | { readonly _tag: "not-found" }
  | { readonly _tag: "unavailable"; readonly reason: string };

function isRecord(input: unknown): input is Readonly<Record<string, unknown>> {
  return typeof input === "object" && input !== null && !Array.isArray(input);
}

async function runCommand(
  command: string,
  args: ReadonlyArray<string>,
  cwd?: string,
): Promise<CommandResult> {
  try {
    const process = Bun.spawn([command, ...args], {
      cwd,
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(process.stdout).text(),
      new Response(process.stderr).text(),
      process.exited,
    ]);
    if (exitCode === 0) return {_tag: "success", stdout, stderr};
    return {_tag: "failure", command, exitCode, stdout, stderr};
  } catch (cause) {
    return {_tag: "failure", command, exitCode: -1, stdout: "", stderr: "", cause};
  }
}

function parseJson(output: string): unknown | undefined {
  try {
    return JSON.parse(output);
  } catch {
    return undefined;
  }
}

function parseWorkspaceList(input: unknown): ReadonlyArray<Workspace> | undefined {
  if (!isRecord(input) || !isRecord(input.result) || !Array.isArray(input.result.workspaces)) {
    return undefined;
  }

  const workspaces: Array<Workspace> = [];
  for (const item of input.result.workspaces) {
    if (!isRecord(item) || typeof item.workspace_id !== "string") return undefined;

    let fallbackCwd: string | undefined;
    if (isRecord(item.worktree) && typeof item.worktree.checkout_path === "string") {
      fallbackCwd = item.worktree.checkout_path;
    }

    if (fallbackCwd) {
      workspaces.push({id: item.workspace_id, fallbackCwd});
    } else {
      workspaces.push({id: item.workspace_id});
    }
  }
  return workspaces;
}

function parsePaneCwd(input: unknown): string | undefined {
  if (!isRecord(input) || !isRecord(input.result) || !Array.isArray(input.result.panes)) {
    return undefined;
  }

  let firstCwd: string | undefined;
  for (const pane of input.result.panes) {
    if (!isRecord(pane)) continue;

    let cwd: string | undefined;
    if (typeof pane.cwd === "string") {
      cwd = pane.cwd;
    } else if (typeof pane.foreground_cwd === "string") {
      cwd = pane.foreground_cwd;
    }
    if (!cwd) continue;
    if (!firstCwd) firstCwd = cwd;
    if (pane.focused === true) return cwd;
  }
  return firstCwd;
}

async function listWorkspaces(): Promise<ReadonlyArray<Workspace> | undefined> {
  const result = await runCommand("herdr", ["workspace", "list"]);
  if (result._tag === "failure") {
    console.error(`[gh-pr-workspace] herdr workspace list failed: ${result.stderr.trim()}`);
    return undefined;
  }
  const workspaces = parseWorkspaceList(parseJson(result.stdout));
  if (!workspaces) console.error("[gh-pr-workspace] invalid herdr workspace list response");
  return workspaces;
}

async function resolveWorkspaceCwd(workspace: Workspace): Promise<string | undefined> {
  const result = await runCommand("herdr", ["pane", "list", "--workspace", workspace.id]);
  if (result._tag === "success") {
    const cwd = parsePaneCwd(parseJson(result.stdout));
    if (cwd) return cwd;
  }
  return workspace.fallbackCwd;
}

async function currentBranch(cwd: string): Promise<string | undefined> {
  const result = await runCommand("git", ["-C", cwd, "branch", "--show-current"]);
  if (result._tag === "failure") return undefined;
  const branch = result.stdout.trim();
  if (!branch) return undefined;
  return branch;
}

async function lookupPullRequest(cwd: string, branch: string): Promise<PullRequestLookup> {
  const fields = [
    "number",
    "state",
    "isDraft",
    "mergeable",
    "mergeStateStatus",
    "reviewDecision",
    "statusCheckRollup",
  ].join(",");
  const result = await runCommand("gh", ["pr", "view", branch, "--json", fields], cwd);
  if (result._tag === "failure") {
    const details = `${result.stdout}\n${result.stderr}`;
    if (details.includes("no pull requests found")) return {_tag: "not-found"};
    return {_tag: "unavailable", reason: result.stderr.trim() || `gh exited ${result.exitCode}`};
  }

  const parsed = parsePullRequest(parseJson(result.stdout));
  if (parsed._tag === "err") {
    return {_tag: "unavailable", reason: parsed.error.message};
  }
  return {_tag: "found", tokens: formatSidebarTokens(parsed.value)};
}

async function clearTokens(workspaceId: string): Promise<void> {
  const args = ["workspace", "report-metadata", workspaceId, "--source", SOURCE];
  for (const token of TOKEN_NAMES) args.push("--clear-token", token);
  const result = await runCommand("herdr", args);
  if (result._tag === "failure") {
    console.error(`[gh-pr-workspace] failed to clear ${workspaceId}: ${result.stderr.trim()}`);
  }
}

async function reportTokens(workspaceId: string, tokens: SidebarTokens): Promise<void> {
  const args = [
    "workspace",
    "report-metadata",
    workspaceId,
    "--source",
    SOURCE,
    "--seq",
    String(Date.now()),
  ];
  const values = {
    pr: tokens.pr,
    merge: tokens.merge,
    ci: tokens.ci,
    review: tokens.review,
  };
  for (const token of TOKEN_NAMES) {
    const value = values[token];
    if (value) args.push("--token", `${token}=${value}`);
    else args.push("--clear-token", token);
  }

  const result = await runCommand("herdr", args);
  if (result._tag === "failure") {
    console.error(`[gh-pr-workspace] failed to report ${workspaceId}: ${result.stderr.trim()}`);
  }
}

async function updateWorkspace(workspace: Workspace): Promise<void> {
  const cwd = await resolveWorkspaceCwd(workspace);
  if (!cwd) {
    await clearTokens(workspace.id);
    return;
  }

  const branch = await currentBranch(cwd);
  if (!branch) {
    await clearTokens(workspace.id);
    return;
  }

  const pullRequest = await lookupPullRequest(cwd, branch);
  if (pullRequest._tag === "found") {
    await reportTokens(workspace.id, pullRequest.tokens);
    return;
  }
  if (pullRequest._tag === "not-found") {
    await clearTokens(workspace.id);
    return;
  }

  console.error(`[gh-pr-workspace] ${workspace.id} (${branch}): ${pullRequest.reason}`);
}

/** Refreshes GitHub PR metadata for every open Herdr repository/worktree workspace. */
export async function updateWorkspacePullRequests(): Promise<void> {
  const workspaces = await listWorkspaces();
  if (!workspaces) return;
  await Promise.all(workspaces.map(updateWorkspace));
}
