type Result<T, E extends Error> =
  | { readonly _tag: "ok"; readonly value: T }
  | { readonly _tag: "err"; readonly error: E };

/** GitHub's lifecycle state for a pull request. */
export type PullRequestState = "OPEN" | "CLOSED" | "MERGED";

/** Parsed GitHub pull request data needed by the sidebar. */
export type PullRequest = {
  readonly number: number;
  readonly state: PullRequestState;
  readonly isDraft: boolean;
  readonly mergeable: string;
  readonly mergeStateStatus: string;
  readonly reviewDecision: string;
  readonly checks: ReadonlyArray<unknown>;
};

/** Named Herdr metadata values rendered on a workspace row. */
export type SidebarTokens = {
  readonly pr: string;
  readonly merge: string;
  readonly ci: string;
  readonly review?: string;
};

/** Indicates that `gh pr view` returned an unexpected JSON shape. */
export class ParsePullRequestError extends Error {
  readonly _tag = "ParsePullRequestError" as const;

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

/**
 * Parses the subset of `gh pr view --json` used by this plugin.
 *
 * @param input - Unknown JSON returned by GitHub CLI.
 * @returns Parsed pull request data, or the first malformed field.
 */
export function parsePullRequest(input: unknown): Result<PullRequest, ParsePullRequestError> {
  if (!isRecord(input)) return { _tag: "err", error: new ParsePullRequestError("root") };

  const state = parseState(input.state);
  if (typeof input.number !== "number") {
    return { _tag: "err", error: new ParsePullRequestError("number") };
  }
  if (!state) return { _tag: "err", error: new ParsePullRequestError("state") };
  if (typeof input.isDraft !== "boolean") {
    return { _tag: "err", error: new ParsePullRequestError("isDraft") };
  }
  if (typeof input.mergeable !== "string") {
    return { _tag: "err", error: new ParsePullRequestError("mergeable") };
  }
  if (typeof input.mergeStateStatus !== "string") {
    return { _tag: "err", error: new ParsePullRequestError("mergeStateStatus") };
  }
  if (typeof input.reviewDecision !== "string") {
    return { _tag: "err", error: new ParsePullRequestError("reviewDecision") };
  }
  if (!Array.isArray(input.statusCheckRollup)) {
    return { _tag: "err", error: new ParsePullRequestError("statusCheckRollup") };
  }

  return {
    _tag: "ok",
    value: {
      number: input.number,
      state,
      isDraft: input.isDraft,
      mergeable: input.mergeable,
      mergeStateStatus: input.mergeStateStatus,
      reviewDecision: input.reviewDecision,
      checks: input.statusCheckRollup,
    },
  };
}

type CiState = "pass" | "fail" | "pending" | "none";

function checkState(input: unknown): Exclude<CiState, "none"> | undefined {
  if (!isRecord(input)) return undefined;

  if (input.__typename === "StatusContext") {
    if (input.state === "ERROR" || input.state === "FAILURE") return "fail";
    if (input.state === "EXPECTED" || input.state === "PENDING") return "pending";
    if (input.state === "SUCCESS") return "pass";
    return undefined;
  }

  if (input.status !== "COMPLETED") return "pending";
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

function rollupChecks(checks: ReadonlyArray<unknown>): CiState {
  const states = new Set(checks.map(checkState).filter((state) => state !== undefined));
  if (states.has("fail")) return "fail";
  if (states.has("pending")) return "pending";
  if (states.has("pass")) return "pass";
  return "none";
}

function mergeLabel(pr: PullRequest): string {
  if (pr.state === "MERGED") return "merged";
  if (pr.state === "CLOSED") return "closed";
  if (pr.isDraft) return "draft";
  if (pr.mergeable === "CONFLICTING" || pr.mergeStateStatus === "DIRTY") return "conflicts";

  const labels: Readonly<Record<string, string>> = {
    BEHIND: "behind",
    BLOCKED: "blocked",
    CLEAN: "mergeable",
    DRAFT: "draft",
    HAS_HOOKS: "checks",
    UNKNOWN: "merge ?",
    UNSTABLE: "unstable",
  };
  return labels[pr.mergeStateStatus] ?? "merge ?";
}

function ciLabel(checks: ReadonlyArray<unknown>): string {
  const labels: Readonly<Record<CiState, string>> = {
    pass: "CI ✓",
    fail: "CI ✗",
    pending: "CI ●",
    none: "CI —",
  };
  return labels[rollupChecks(checks)];
}

function reviewLabel(reviewDecision: string): string | undefined {
  const labels: Readonly<Record<string, string>> = {
    APPROVED: "review ✓",
    CHANGES_REQUESTED: "changes requested",
    REVIEW_REQUIRED: "review needed",
  };
  return labels[reviewDecision];
}

/**
 * Formats parsed pull request state as compact Herdr workspace tokens.
 *
 * @param pr - Parsed GitHub pull request data.
 * @returns Tokens for PR identity, mergeability, CI, and optional review state.
 */
export function formatSidebarTokens(pr: PullRequest): SidebarTokens {
  const review = reviewLabel(pr.reviewDecision);
  const required = {
    pr: `#${pr.number}`,
    merge: mergeLabel(pr),
    ci: ciLabel(pr.checks),
  };
  if (!review) return required;
  return {...required, review};
}
