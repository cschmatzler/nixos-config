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

type Unavailable = {
  readonly _tag: "unavailable";
  readonly reason: string;
};

type Workspace = {
  readonly id: string;
  readonly worktreeCwd?: string;
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
  | { readonly _tag: "found"; readonly status: WorkspacePrStatus }
  | { readonly _tag: "not-found" }
  | Unavailable;

type WorkspaceStatus =
  | { readonly _tag: "clear" }
  | { readonly _tag: "report"; readonly status: WorkspacePrStatus };

type WorkspaceStatusDecision =
  | WorkspaceStatus
  | { readonly _tag: "preserve"; readonly reason: string; readonly branch?: string };

type StatusWrite = { readonly _tag: "written" } | Unavailable;

type Result<T, E> =
  | { readonly _tag: "ok"; readonly value: T }
  | { readonly _tag: "err"; readonly error: E };

type PullRequestState = "OPEN" | "CLOSED" | "MERGED";
type Mergeability = "MERGEABLE" | "CONFLICTING" | "UNKNOWN";
type MergeState =
  | "BEHIND"
  | "BLOCKED"
  | "CLEAN"
  | "DIRTY"
  | "DRAFT"
  | "HAS_HOOKS"
  | "UNKNOWN"
  | "UNSTABLE";
type CheckState = "pass" | "fail" | "pending";
type CiState = CheckState | "none";

type PullRequest = {
  readonly number: number;
  readonly state: PullRequestState;
  readonly isDraft: boolean;
  readonly mergeability: Mergeability;
  readonly mergeState: MergeState;
  readonly checks: ReadonlyArray<CheckState>;
};

type PullRequestIdentity = {
  readonly number: number;
};

type WorkspacePrMergeability = "merged" | "mergeable" | "not-mergeable" | "unknown";

type WorkspacePrStatus = {
  readonly pullRequest: PullRequestIdentity;
  readonly mergeability: WorkspacePrMergeability;
  readonly ci: CiState;
};

type InvalidPullRequest = {
  readonly _tag: "invalid-pull-request";
  readonly field: string;
};

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

/** Concrete process seam shared by the private GitHub, Git, and Herdr adapters. */
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

function parseJson(output: string): Result<unknown, Unavailable> {
  try {
    return { _tag: "ok", value: JSON.parse(output) };
  } catch {
    return { _tag: "err", error: { _tag: "unavailable", reason: "invalid JSON response" } };
  }
}

// Herdr adapter: discovers workspace inputs and renders the final owned status.

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

async function discoverWorkspaces(
  herdrBin: string,
  workspaceId?: string,
): Promise<WorkspaceList> {
  const result = await runCommand(herdrBin, ["workspace", "list"]);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (json._tag === "err") return json.error;

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
  if (json._tag === "err") return json.error;
  return parsePaneCwd(json.value);
}

type SidebarTokens = {
  readonly pr: string;
  readonly merge: string;
  readonly ci: string;
};

function renderSidebarTokens(status: WorkspacePrStatus): SidebarTokens {
  const mergeLabels: Readonly<Record<WorkspacePrMergeability, string>> = {
    merged: "◆",
    mergeable: "✓",
    "not-mergeable": "✗",
    unknown: "?",
  };
  const ciLabels: Readonly<Record<CiState, string>> = {
    pass: "CI ✓",
    fail: "CI ✗",
    pending: "CI ●",
    none: "CI —",
  };

  return {
    pr: `#${status.pullRequest.number}`,
    merge: mergeLabels[status.mergeability],
    ci: ciLabels[status.ci],
  };
}

async function renderWorkspaceStatus(
  herdrBin: string,
  workspaceId: string,
  sequence: bigint,
  status: WorkspaceStatus,
): Promise<StatusWrite> {
  const args = [
    "workspace",
    "report-metadata",
    workspaceId,
    "--source",
    SOURCE,
    "--seq",
    String(sequence),
  ];
  if (status._tag === "report") {
    const tokens = renderSidebarTokens(status.status);
    for (const token of TOKEN_NAMES) {
      args.push("--token", `${token}=${tokens[token]}`);
    }
  } else {
    for (const token of TOKEN_NAMES) {
      args.push("--clear-token", token);
    }
  }

  const result = await runCommand(herdrBin, args);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }
  return { _tag: "written" };
}

const herdrAdapter = {
  discoverWorkspaces,
  resolveWorkspaceCwd,
  renderWorkspaceStatus,
};

// Git adapter: resolves repository state without treating detached HEAD as unavailable.

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

const gitAdapter = {
  currentBranch,
  currentRevision,
};

// GitHub adapter: owns CLI requests, response parsing, and exact-revision fallback.

function invalidPullRequest(field: string): Result<never, InvalidPullRequest> {
  return { _tag: "err", error: { _tag: "invalid-pull-request", field } };
}

function parseState(input: unknown): PullRequestState | undefined {
  if (input === "OPEN" || input === "CLOSED" || input === "MERGED") return input;
  return undefined;
}

function parseMergeability(input: unknown): Mergeability | undefined {
  if (input === "MERGEABLE" || input === "CONFLICTING" || input === "UNKNOWN") return input;
  return undefined;
}

function parseMergeState(input: unknown): MergeState | undefined {
  if (
    input === "BEHIND" ||
    input === "BLOCKED" ||
    input === "CLEAN" ||
    input === "DIRTY" ||
    input === "DRAFT" ||
    input === "HAS_HOOKS" ||
    input === "UNKNOWN" ||
    input === "UNSTABLE"
  ) {
    return input;
  }
  return undefined;
}

function parseCheckState(input: unknown): CheckState | undefined {
  if (!isRecord(input)) return undefined;

  if (input.__typename === "StatusContext") {
    if (input.state === "ERROR" || input.state === "FAILURE") return "fail";
    if (input.state === "EXPECTED" || input.state === "PENDING") return "pending";
    if (input.state === "SUCCESS") return "pass";
    return undefined;
  }

  if (input.__typename !== "CheckRun") return undefined;
  if (
    input.status === "IN_PROGRESS" ||
    input.status === "PENDING" ||
    input.status === "QUEUED" ||
    input.status === "REQUESTED" ||
    input.status === "WAITING"
  ) {
    return "pending";
  }
  if (input.status !== "COMPLETED") return undefined;

  if (
    input.conclusion === "ACTION_REQUIRED" ||
    input.conclusion === "CANCELLED" ||
    input.conclusion === "FAILURE" ||
    input.conclusion === "STARTUP_FAILURE" ||
    input.conclusion === "TIMED_OUT"
  ) {
    return "fail";
  }
  if (
    input.conclusion === "NEUTRAL" ||
    input.conclusion === "SKIPPED" ||
    input.conclusion === "STALE" ||
    input.conclusion === "SUCCESS"
  ) {
    return "pass";
  }
  return undefined;
}

function parsePullRequest(input: unknown): Result<PullRequest, InvalidPullRequest> {
  if (!isRecord(input)) return invalidPullRequest("root");
  if (typeof input.number !== "number" || !Number.isSafeInteger(input.number) || input.number < 1) {
    return invalidPullRequest("number");
  }

  const state = parseState(input.state);
  if (!state) return invalidPullRequest("state");
  if (typeof input.isDraft !== "boolean") return invalidPullRequest("isDraft");

  const mergeability = parseMergeability(input.mergeable);
  if (!mergeability) return invalidPullRequest("mergeable");
  const mergeState = parseMergeState(input.mergeStateStatus);
  if (!mergeState) return invalidPullRequest("mergeStateStatus");
  if (!Array.isArray(input.statusCheckRollup)) return invalidPullRequest("statusCheckRollup");

  const checks: Array<CheckState> = [];
  for (const [index, check] of input.statusCheckRollup.entries()) {
    const state = parseCheckState(check);
    if (!state) return invalidPullRequest(`statusCheckRollup[${index}]`);
    checks.push(state);
  }

  return {
    _tag: "ok",
    value: {
      number: input.number,
      state,
      isDraft: input.isDraft,
      mergeability,
      mergeState,
      checks,
    },
  };
}

function rollupChecks(checks: ReadonlyArray<CheckState>): CiState {
  const states = new Set(checks);
  if (states.has("fail")) return "fail";
  if (states.has("pending")) return "pending";
  if (states.has("pass")) return "pass";
  return "none";
}

function workspacePrMergeability(pr: PullRequest): WorkspacePrMergeability {
  if (pr.state === "MERGED") return "merged";
  if (pr.state === "CLOSED" || pr.isDraft) return "not-mergeable";
  if (pr.mergeability === "UNKNOWN" || pr.mergeState === "UNKNOWN") return "unknown";
  if (pr.mergeability === "MERGEABLE" && pr.mergeState === "CLEAN") return "mergeable";
  return "not-mergeable";
}

function parseWorkspacePrStatus(
  input: unknown,
): Result<WorkspacePrStatus, InvalidPullRequest> {
  const parsed = parsePullRequest(input);
  if (parsed._tag === "err") return parsed;

  return {
    _tag: "ok",
    value: {
      pullRequest: { number: parsed.value.number },
      mergeability: workspacePrMergeability(parsed.value),
      ci: rollupChecks(parsed.value.checks),
    },
  };
}

async function currentRepository(cwd: string): Promise<RepositoryLookup> {
  const result = await runCommand("gh", ["repo", "view", "--json", "nameWithOwner"], cwd);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (
    json._tag === "err" ||
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
  const revision = await gitAdapter.currentRevision(cwd);
  if (revision._tag === "unavailable") return revision;

  const repository = await currentRepository(cwd);
  if (repository._tag === "unavailable") return repository;

  const endpoint = `repos/${repository.repository}/commits/${revision.revision}/pulls?per_page=100`;
  const result = await runCommand("gh", ["api", endpoint], cwd);
  if (result._tag === "failure") {
    return { _tag: "unavailable", reason: failureReason(result) };
  }

  const json = parseJson(result.stdout);
  if (json._tag === "err") return json.error;
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
  if (json._tag === "err") return json.error;

  const parsed = parseWorkspacePrStatus(json.value);
  if (parsed._tag === "err") {
    return {
      _tag: "unavailable",
      reason: `Invalid GitHub pull request field: ${parsed.error.field}`,
    };
  }
  return { _tag: "found", status: parsed.value };
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

const githubAdapter = {
  lookupPullRequest,
};

async function decideWorkspaceStatus(
  herdrBin: string,
  workspace: Workspace,
): Promise<WorkspaceStatusDecision> {
  const cwd = await herdrAdapter.resolveWorkspaceCwd(herdrBin, workspace);
  if (cwd._tag === "unavailable") {
    return { _tag: "preserve", reason: cwd.reason };
  }

  const branch = await gitAdapter.currentBranch(cwd.cwd);
  if (branch._tag === "unavailable") {
    return { _tag: "preserve", reason: branch.reason };
  }
  if (branch._tag === "no-branch") return { _tag: "clear" };

  const pullRequest = await githubAdapter.lookupPullRequest(cwd.cwd, branch.branch);
  if (pullRequest._tag === "found") {
    return { _tag: "report", status: pullRequest.status };
  }
  if (pullRequest._tag === "not-found") return { _tag: "clear" };
  return { _tag: "preserve", reason: pullRequest.reason, branch: branch.branch };
}

async function refreshWorkspace(
  herdrBin: string,
  workspace: Workspace,
  sequence: bigint,
): Promise<void> {
  const decision = await decideWorkspaceStatus(herdrBin, workspace);
  if (decision._tag === "preserve") {
    const context =
      decision.branch === undefined ? workspace.id : `${workspace.id} (${decision.branch})`;
    console.error(`[gh-pr-workspace] ${context}: ${decision.reason}; preserving current status`);
    return;
  }

  const write = await herdrAdapter.renderWorkspaceStatus(
    herdrBin,
    workspace.id,
    sequence,
    decision,
  );
  if (write._tag === "unavailable") {
    console.error(
      `[gh-pr-workspace] failed to ${decision._tag} ${workspace.id}: ${write.reason}`,
    );
  }
}

function currentSequence(): bigint {
  const epochMicroseconds = (performance.timeOrigin + performance.now()) * 1_000;
  return BigInt(Math.floor(epochMicroseconds));
}

/**
 * Refreshes Workspace PR Status for one event workspace or every open workspace.
 *
 * Expected directory, Git, GitHub, and Herdr failures are handled as tagged outcomes here.
 * Only unexpected failures escape to the executable entry point.
 */
export async function refreshWorkspacePrStatus(
  herdrBin: string,
  workspaceId?: string,
): Promise<void> {
  const workspaces = await herdrAdapter.discoverWorkspaces(herdrBin, workspaceId);
  if (workspaces._tag === "unavailable") {
    console.error(`[gh-pr-workspace] unable to list workspaces: ${workspaces.reason}`);
    return;
  }

  const sequence = currentSequence();
  await Promise.all(
    workspaces.workspaces.map((workspace) => refreshWorkspace(herdrBin, workspace, sequence)),
  );
}
