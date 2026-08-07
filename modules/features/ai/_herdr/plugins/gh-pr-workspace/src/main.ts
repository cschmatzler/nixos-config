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

type Unavailable = {
  readonly _tag: "unavailable";
  readonly reason: string;
};

type WorkspaceList =
  | {readonly _tag: "found"; readonly workspaces: ReadonlyArray<Workspace>}
  | Unavailable;

type WorkspaceCwd = {readonly _tag: "found"; readonly cwd: string} | Unavailable;

type BranchLookup =
  | {readonly _tag: "found"; readonly branch: string}
  | {readonly _tag: "no-branch"}
  | Unavailable;

type PullRequestLookup =
  | {readonly _tag: "found"; readonly tokens: SidebarTokens}
  | {readonly _tag: "not-found"}
  | Unavailable;

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

function parseJson(output: string): {readonly _tag: "ok"; readonly value: unknown} | Unavailable {
  try {
    return {_tag: "ok", value: JSON.parse(output)};
  } catch {
    return {_tag: "unavailable", reason: "invalid JSON response"};
  }
}

function parseWorkspaceList(input: unknown): WorkspaceList {
  if (!isRecord(input) || !isRecord(input.result) || !Array.isArray(input.result.workspaces)) {
    return {_tag: "unavailable", reason: "invalid Herdr workspace list response"};
  }

  const workspaces: Array<Workspace> = [];
  for (const item of input.result.workspaces) {
    if (!isRecord(item) || typeof item.workspace_id !== "string") {
      return {_tag: "unavailable", reason: "invalid Herdr workspace entry"};
    }

    if (isRecord(item.worktree) && typeof item.worktree.checkout_path === "string") {
      workspaces.push({id: item.workspace_id, fallbackCwd: item.worktree.checkout_path});
    } else {
      workspaces.push({id: item.workspace_id});
    }
  }
  return {_tag: "found", workspaces};
}

function parsePaneCwd(input: unknown): WorkspaceCwd {
  if (!isRecord(input) || !isRecord(input.result) || !Array.isArray(input.result.panes)) {
    return {_tag: "unavailable", reason: "invalid Herdr pane list response"};
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
    if (pane.focused === true) return {_tag: "found", cwd};
  }

  if (firstCwd) return {_tag: "found", cwd: firstCwd};
  return {_tag: "unavailable", reason: "workspace has no available directory"};
}

async function listWorkspaces(herdrBin: string): Promise<WorkspaceList> {
  const result = await runCommand(herdrBin, ["workspace", "list"]);
  if (result._tag === "failure") {
    return {
      _tag: "unavailable",
      reason: result.stderr.trim() || `herdr exited ${result.exitCode}`,
    };
  }

  const parsed = parseJson(result.stdout);
  if (parsed._tag === "unavailable") return parsed;
  return parseWorkspaceList(parsed.value);
}

async function resolveWorkspaceCwd(
  herdrBin: string,
  workspace: Workspace,
): Promise<WorkspaceCwd> {
  const result = await runCommand(herdrBin, ["pane", "list", "--workspace", workspace.id]);
  if (result._tag === "success") {
    const parsed = parseJson(result.stdout);
    if (parsed._tag === "ok") {
      const cwd = parsePaneCwd(parsed.value);
      if (cwd._tag === "found") return cwd;
    }
  }

  if (workspace.fallbackCwd) return {_tag: "found", cwd: workspace.fallbackCwd};
  if (result._tag === "failure") {
    return {
      _tag: "unavailable",
      reason: result.stderr.trim() || `herdr exited ${result.exitCode}`,
    };
  }
  return {_tag: "unavailable", reason: "workspace directory is unavailable"};
}

async function currentBranch(cwd: string): Promise<BranchLookup> {
  const result = await runCommand("git", ["-C", cwd, "branch", "--show-current"]);
  if (result._tag === "failure") {
    return {_tag: "unavailable", reason: result.stderr.trim() || `git exited ${result.exitCode}`};
  }

  const branch = result.stdout.trim();
  if (!branch) return {_tag: "no-branch"};
  return {_tag: "found", branch};
}

async function lookupPullRequest(cwd: string, branch: string): Promise<PullRequestLookup> {
  const fields = [
    "number",
    "state",
    "isDraft",
    "mergeable",
    "mergeStateStatus",
    "statusCheckRollup",
  ].join(",");
  const result = await runCommand("gh", ["pr", "view", branch, "--json", fields], cwd);
  if (result._tag === "failure") {
    const details = `${result.stdout}\n${result.stderr}`.toLowerCase();
    if (details.includes("no pull requests found")) return {_tag: "not-found"};
    return {_tag: "unavailable", reason: result.stderr.trim() || `gh exited ${result.exitCode}`};
  }

  const json = parseJson(result.stdout);
  if (json._tag === "unavailable") return json;
  const parsed = parsePullRequest(json.value);
  if (parsed._tag === "err") {
    return {_tag: "unavailable", reason: parsed.error.message};
  }
  return {_tag: "found", tokens: formatSidebarTokens(parsed.value)};
}

async function clearTokens(
  herdrBin: string,
  workspaceId: string,
  sequence: bigint,
): Promise<CommandResult> {
  const args = [
    "workspace",
    "report-metadata",
    workspaceId,
    "--source",
    SOURCE,
    "--seq",
    String(sequence),
  ];
  for (const token of TOKEN_NAMES) args.push("--clear-token", token);
  return runCommand(herdrBin, args);
}

async function reportTokens(
  herdrBin: string,
  workspaceId: string,
  sequence: bigint,
  tokens: SidebarTokens,
): Promise<CommandResult> {
  const args = [
    "workspace",
    "report-metadata",
    workspaceId,
    "--source",
    SOURCE,
    "--seq",
    String(sequence),
  ];
  const values = {
    pr: tokens.pr,
    merge: tokens.merge,
    ci: tokens.ci,
    review: undefined,
  };
  for (const token of TOKEN_NAMES) {
    const value = values[token];
    if (value) args.push("--token", `${token}=${value}`);
    else args.push("--clear-token", token);
  }

  return runCommand(herdrBin, args);
}

function logWriteFailure(operation: "clear" | "report", workspaceId: string, result: CommandFailure) {
  const reason = result.stderr.trim() || `${result.command} exited ${result.exitCode}`;
  console.error(`[gh-pr-workspace] failed to ${operation} ${workspaceId}: ${reason}`);
}

async function updateWorkspace(
  herdrBin: string,
  workspace: Workspace,
  sequence: bigint,
): Promise<void> {
  const cwd = await resolveWorkspaceCwd(herdrBin, workspace);
  if (cwd._tag === "unavailable") {
    console.error(`[gh-pr-workspace] ${workspace.id}: ${cwd.reason}; preserving current status`);
    return;
  }

  const branch = await currentBranch(cwd.cwd);
  if (branch._tag === "unavailable") {
    console.error(`[gh-pr-workspace] ${workspace.id}: ${branch.reason}; preserving current status`);
    return;
  }
  if (branch._tag === "no-branch") {
    const result = await clearTokens(herdrBin, workspace.id, sequence);
    if (result._tag === "failure") logWriteFailure("clear", workspace.id, result);
    return;
  }

  const pullRequest = await lookupPullRequest(cwd.cwd, branch.branch);
  if (pullRequest._tag === "found") {
    const result = await reportTokens(herdrBin, workspace.id, sequence, pullRequest.tokens);
    if (result._tag === "failure") logWriteFailure("report", workspace.id, result);
    return;
  }
  if (pullRequest._tag === "not-found") {
    const result = await clearTokens(herdrBin, workspace.id, sequence);
    if (result._tag === "failure") logWriteFailure("clear", workspace.id, result);
    return;
  }

  console.error(
    `[gh-pr-workspace] ${workspace.id} (${branch.branch}): ${pullRequest.reason}; preserving current status`,
  );
}

/**
 * Refreshes GitHub pull request status for every open Herdr repository/worktree workspace.
 *
 * Unavailable workspace, Git, or GitHub data preserves the last successfully reported status.
 * A successful no-branch result or confirmed missing pull request clears the owned status.
 *
 * @param herdrBin - Herdr binary injected into the plugin runtime.
 */
export async function updateWorkspacePullRequests(herdrBin: string): Promise<void> {
  const workspaces = await listWorkspaces(herdrBin);
  if (workspaces._tag === "unavailable") {
    console.error(`[gh-pr-workspace] unable to list workspaces: ${workspaces.reason}`);
    return;
  }

  const sequence = BigInt(Date.now()) * 1_000_000n;
  await Promise.all(
    workspaces.workspaces.map((workspace) => updateWorkspace(herdrBin, workspace, sequence)),
  );
}
