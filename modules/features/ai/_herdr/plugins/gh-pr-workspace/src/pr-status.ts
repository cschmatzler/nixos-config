type Result<T, E extends Error> =
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

/** Named Herdr metadata values rendered on a workspace row. */
export type SidebarTokens = {
  readonly pr: string;
  readonly merge: string;
  readonly ci: string;
};

/** Indicates that GitHub CLI returned an unexpected pull request shape. */
export class ParseWorkspacePrStatusError extends Error {
  readonly _tag = "ParseWorkspacePrStatusError" as const;

  constructor(readonly field: string) {
    super(`Invalid GitHub pull request field: ${field}`);
  }
}

function isRecord(input: unknown): input is Readonly<Record<string, unknown>> {
  return typeof input === "object" && input !== null && !Array.isArray(input);
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

function invalid(field: string): { readonly _tag: "err"; readonly error: ParseWorkspacePrStatusError } {
  return { _tag: "err", error: new ParseWorkspacePrStatusError(field) };
}

function parsePullRequest(input: unknown): Result<PullRequest, ParseWorkspacePrStatusError> {
  if (!isRecord(input)) return invalid("root");
  if (typeof input.number !== "number" || !Number.isSafeInteger(input.number) || input.number < 1) {
    return invalid("number");
  }

  const state = parseState(input.state);
  if (!state) return invalid("state");
  if (typeof input.isDraft !== "boolean") return invalid("isDraft");

  const mergeability = parseMergeability(input.mergeable);
  if (!mergeability) return invalid("mergeable");
  const mergeState = parseMergeState(input.mergeStateStatus);
  if (!mergeState) return invalid("mergeStateStatus");
  if (!Array.isArray(input.statusCheckRollup)) return invalid("statusCheckRollup");

  const checks: Array<CheckState> = [];
  for (const [index, check] of input.statusCheckRollup.entries()) {
    const state = parseCheckState(check);
    if (!state) return invalid(`statusCheckRollup[${index}]`);
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

function mergeLabel(pr: PullRequest): string {
  if (pr.state === "MERGED") return "◆";
  if (pr.state === "CLOSED" || pr.isDraft) return "✗";
  if (pr.mergeability === "UNKNOWN" || pr.mergeState === "UNKNOWN") return "?";
  if (pr.mergeability === "MERGEABLE" && pr.mergeState === "CLEAN") return "✓";
  return "✗";
}

function ciLabel(checks: ReadonlyArray<CheckState>): string {
  const labels: Readonly<Record<CiState, string>> = {
    pass: "CI ✓",
    fail: "CI ✗",
    pending: "CI ●",
    none: "CI —",
  };
  return labels[rollupChecks(checks)];
}

/**
 * Parses GitHub CLI pull request output into compact Herdr workspace tokens.
 *
 * @param input - Unknown JSON returned by `gh pr view --json`.
 * @returns Sidebar tokens, or the first malformed or unsupported field.
 */
export function parseWorkspacePrStatus(
  input: unknown,
): Result<SidebarTokens, ParseWorkspacePrStatusError> {
  const parsed = parsePullRequest(input);
  if (parsed._tag === "err") return parsed;

  return {
    _tag: "ok",
    value: {
      pr: `#${parsed.value.number}`,
      merge: mergeLabel(parsed.value),
      ci: ciLabel(parsed.value.checks),
    },
  };
}
