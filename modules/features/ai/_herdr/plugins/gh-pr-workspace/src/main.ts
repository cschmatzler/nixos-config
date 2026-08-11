import { parseWorkspacePrStatus, type SidebarTokens } from "./pr-status";

const SOURCE = "gh-pr-workspace";
const TOKEN_NAMES = ["pr", "merge", "ci"] as const;
const PULL_REQUEST_FIELDS = [
  "number",
  "state",
  "isDraft",
  "mergeable",
  "mergeStateStatus",
  "statusCheckRollup",
].join(",");

type CommandSuccess = {
  readonly _tag: "success";
  readonly stdout: string;
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
  readonly worktreeCwd?: string;
};

type Unavailable = {
  readonly _tag: "unavailable";
  readonly reason: string;
};

type WorkspaceList =
  | { readonly _tag: "found"; readonly workspaces: ReadonlyArray<Workspace> }
  | Unavailable;

type WorkspaceCwd = { readonly _tag: "found"; readonly cwd: string } | Unavailable;

type BranchLookup =
  | { readonly _tag: "found"; readonly branch: string }
  | { readonly _tag: "no-branch" }
  | Unavailable;

type RevisionLookup = { readonly _tag: "found"; readonly revision: string } | Unavailable;

type RepositoryLookup = { readonly _tag: "found"; readonly repository: string } | Unavailable;

type PullRequestReferenceLookup =
  | { readonly _tag: "found"; readonly number: number }
  | { readonly _tag: "not-found" }
  | Unavailable;

type PullRequestLookup =
  | { readonly _tag: "found"; readonly tokens: SidebarTokens }
  | { readonly _tag: "not-found" }
  | Unavailable;

type WorkspaceStatusWrite =
  | { readonly _tag: "clear" }
  | { readonly _tag: "report"; readonly tokens: SidebarTokens };

function isRecord(input: unknown): input is Readonly<Record<string, unknown>> {
  return typeof input === "object" && input !== null && !Array.isArray(input);
}

function spawnCommand(command: string, args: ReadonlyArray<string>, cwd?: string) {
  const commandLine = [command, ...args];
  if (cwd === undefined) {
    return Bun.spawn(commandLine, { stdout: "pipe", stderr: "pipe" });
  }
  return Bun.spawn(commandLine, { cwd, stdout: "pipe", stderr: "pipe" });
}

async function runCommand(
  command: string,
  args: ReadonlyArray<string>,
  cwd?: string,
): Promise<CommandResult> {
  try {
    const process = spawnCommand(command, args, cwd);
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(process.stdout).text(),
      new Response(process.stderr).text(),
      process.exited,
    ]);
    if (exitCode === 0) return { _tag: "success", stdout };
    return { _tag: "failure", command, exitCode, stdout, stderr };
  } catch (cause) {
    return { _tag: "failure", command, exitCode: -1, stdout: "", stderr: "", cause };
  }
}

function failureReason(result: CommandFailure): string {
  const stderr = result.stderr.trim();
  if (stderr) return stderr;

  const stdout = result.stdout.trim();
  if (stdout) return stdout;
  if (result.cause instanceof Error) return result.cause.message;
  if (result.cause !== undefined) return String(result.cause);
  return `${result.command} exited ${result.exitCode}`;
}

function parseJson(output: string): { readonly _tag: "ok"; readonly value: unknown } | Unavailable {
  try {
    return { _tag: "ok", value: JSON.parse(output) };
  } catch {
    return { _tag: "unavailable", reason: "invalid JSON response" };
  }
}

function parseWorkspaceList(input: unknown): WorkspaceList {
  if (!isRecord(input) || !isRecord(input.result) || !Array.isArray(input.result.workspaces)) {
    return { _tag: "unavailable", reason: "invalid Herdr workspace list response" };
  }

  const workspaces: Array<Workspace> = [];
  for (const item of input.result.workspaces) {
    if (!isRecord(item) || typeof item.workspace_id !== "string") {
      return { _tag: "unavailable", reason: "invalid Herdr workspace entry" };
    }

    if (isRecord(item.worktree) && typeof item.worktree.checkout_path === "string") {
      workspaces.push({ id: item.workspace_id, worktreeCwd: item.worktree.checkout_path });
    } else {
      workspaces.push({ id: item.workspace_id });
    }
  }
  return { _tag: "found", workspaces };
}

function parsePaneCwd(input: unknown): WorkspaceCwd {
  if (!isRecord(input) || !isRecord(input.result) || !Array.isArray(input.result.panes)) {
    return { _tag: "unavailable", reason: "invalid Herdr pane list response" };
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
    if (pane.focused === true) return { _tag: "found", cwd };
  }

  if (firstCwd) return { _tag: "found", cwd: firstCwd };
  return { _tag: "unavailable", reason: "workspace has no available directory" };
}

async function listWorkspaces(
  herdrBin: string,
  workspaceId?: string,
): Promise<WorkspaceList> {
  const result = await runCommand(herdrBin, ["workspace", "list"]);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (json._tag === "unavailable") return json;

  const parsed = parseWorkspaceList(json.value);
  if (parsed._tag === "unavailable" || workspaceId === undefined) return parsed;

  return {
    _tag: "found",
    workspaces: parsed.workspaces.filter((workspace) => workspace.id === workspaceId),
  };
}

async function resolveWorkspaceCwd(
  herdrBin: string,
  workspace: Workspace,
): Promise<WorkspaceCwd> {
  if (workspace.worktreeCwd) return { _tag: "found", cwd: workspace.worktreeCwd };

  const result = await runCommand(herdrBin, ["pane", "list", "--workspace", workspace.id]);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (json._tag === "unavailable") return json;
  return parsePaneCwd(json.value);
}

async function currentBranch(cwd: string): Promise<BranchLookup> {
  const result = await runCommand("git", ["-C", cwd, "branch", "--show-current"]);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const branch = result.stdout.trim();
  if (!branch) return { _tag: "no-branch" };
  return { _tag: "found", branch };
}

async function currentRevision(cwd: string): Promise<RevisionLookup> {
  const result = await runCommand("git", ["-C", cwd, "rev-parse", "HEAD"]);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const revision = result.stdout.trim();
  if (!/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/.test(revision)) {
    return { _tag: "unavailable", reason: "invalid Git revision" };
  }
  return { _tag: "found", revision };
}

async function currentRepository(cwd: string): Promise<RepositoryLookup> {
  const result = await runCommand("gh", ["repo", "view", "--json", "nameWithOwner"], cwd);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (
    json._tag === "unavailable" ||
    !isRecord(json.value) ||
    typeof json.value.nameWithOwner !== "string" ||
    !/^[^/\s]+\/[^/\s]+$/.test(json.value.nameWithOwner)
  ) {
    return { _tag: "unavailable", reason: "invalid GitHub repository response" };
  }
  return { _tag: "found", repository: json.value.nameWithOwner };
}

function parseRevisionPullRequest(
  input: unknown,
  revision: string,
): PullRequestReferenceLookup {
  if (!Array.isArray(input)) {
    return { _tag: "unavailable", reason: "invalid GitHub commit pull request response" };
  }

  const matching: Array<{ readonly number: number; readonly state: "open" | "closed" }> = [];
  for (const item of input) {
    if (
      !isRecord(item) ||
      typeof item.number !== "number" ||
      !Number.isSafeInteger(item.number) ||
      item.number < 1 ||
      (item.state !== "open" && item.state !== "closed") ||
      !isRecord(item.head) ||
      typeof item.head.sha !== "string"
    ) {
      return { _tag: "unavailable", reason: "invalid GitHub commit pull request entry" };
    }
    if (item.head.sha === revision) {
      matching.push({ number: item.number, state: item.state });
    }
  }

  const open = matching.filter((pullRequest) => pullRequest.state === "open");
  const [onlyOpen] = open;
  if (open.length === 1 && onlyOpen !== undefined) {
    return { _tag: "found", number: onlyOpen.number };
  }
  if (open.length > 1) {
    return {
      _tag: "unavailable",
      reason: "multiple open pull requests share the current revision",
    };
  }

  const [onlyMatch] = matching;
  if (matching.length === 1 && onlyMatch !== undefined) {
    return { _tag: "found", number: onlyMatch.number };
  }
  if (matching.length === 0) return { _tag: "not-found" };
  return { _tag: "unavailable", reason: "multiple pull requests share the current revision" };
}

async function findPullRequestByRevision(cwd: string): Promise<PullRequestReferenceLookup> {
  const revision = await currentRevision(cwd);
  if (revision._tag === "unavailable") return revision;

  const repository = await currentRepository(cwd);
  if (repository._tag === "unavailable") return repository;

  const endpoint = `repos/${repository.repository}/commits/${revision.revision}/pulls?per_page=100`;
  const result = await runCommand("gh", ["api", endpoint], cwd);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (json._tag === "unavailable") return json;
  return parseRevisionPullRequest(json.value, revision.revision);
}

async function viewPullRequest(cwd: string, selector: string): Promise<PullRequestLookup> {
  const result = await runCommand(
    "gh",
    ["pr", "view", selector, "--json", PULL_REQUEST_FIELDS],
    cwd,
  );
  if (result._tag === "failure") {
    const details = `${result.stdout}\n${result.stderr}`.toLowerCase();
    if (details.includes("no pull requests found")) return { _tag: "not-found" };
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (json._tag === "unavailable") return json;

  const parsed = parseWorkspacePrStatus(json.value);
  if (parsed._tag === "err") {
    return { _tag: "unavailable", reason: parsed.error.message };
  }
  return { _tag: "found", tokens: parsed.value };
}

async function lookupPullRequest(cwd: string, branch: string): Promise<PullRequestLookup> {
  const branchPullRequest = await viewPullRequest(cwd, branch);
  if (branchPullRequest._tag !== "not-found") return branchPullRequest;

  // An agent may push a Herdr worktree under a PR-specific remote branch while
  // retaining the generated local branch name. Match only an exact PR head revision.
  const revisionPullRequest = await findPullRequestByRevision(cwd);
  if (revisionPullRequest._tag !== "found") return revisionPullRequest;
  return viewPullRequest(cwd, String(revisionPullRequest.number));
}

async function writeWorkspaceStatus(
  herdrBin: string,
  workspaceId: string,
  sequence: bigint,
  status: WorkspaceStatusWrite,
): Promise<void> {
  const args = [
    "workspace",
    "report-metadata",
    workspaceId,
    "--source",
    SOURCE,
    "--seq",
    String(sequence),
  ];
  for (const token of TOKEN_NAMES) {
    if (status._tag === "report") {
      args.push("--token", `${token}=${status.tokens[token]}`);
    } else {
      args.push("--clear-token", token);
    }
  }

  const result = await runCommand(herdrBin, args);
  if (result._tag === "failure") {
    console.error(
      `[gh-pr-workspace] failed to ${status._tag} ${workspaceId}: ${failureReason(result)}`,
    );
  }
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
    await writeWorkspaceStatus(herdrBin, workspace.id, sequence, { _tag: "clear" });
    return;
  }

  const pullRequest = await lookupPullRequest(cwd.cwd, branch.branch);
  if (pullRequest._tag === "found") {
    await writeWorkspaceStatus(herdrBin, workspace.id, sequence, {
      _tag: "report",
      tokens: pullRequest.tokens,
    });
    return;
  }
  if (pullRequest._tag === "not-found") {
    await writeWorkspaceStatus(herdrBin, workspace.id, sequence, { _tag: "clear" });
    return;
  }

  console.error(
    `[gh-pr-workspace] ${workspace.id} (${branch.branch}): ${pullRequest.reason}; preserving current status`,
  );
}

function currentSequence(): bigint {
  const epochMicroseconds = (performance.timeOrigin + performance.now()) * 1_000;
  return BigInt(Math.floor(epochMicroseconds));
}

/**
 * Refreshes GitHub pull request status for open Herdr workspaces.
 *
 * Unavailable workspace, Git, or GitHub data preserves the last successfully reported status.
 * A successful no-branch result or confirmed missing pull request clears the owned status.
 *
 * @param herdrBin - Herdr binary injected into the plugin runtime.
 * @param workspaceId - Optional event workspace to refresh instead of every open workspace.
 */
export async function updateWorkspacePullRequests(
  herdrBin: string,
  workspaceId?: string,
): Promise<void> {
  const workspaces = await listWorkspaces(herdrBin, workspaceId);
  if (workspaces._tag === "unavailable") {
    console.error(`[gh-pr-workspace] unable to list workspaces: ${workspaces.reason}`);
    return;
  }

  const sequence = currentSequence();
  await Promise.all(
    workspaces.workspaces.map((workspace) => updateWorkspace(herdrBin, workspace, sequence)),
  );
}
