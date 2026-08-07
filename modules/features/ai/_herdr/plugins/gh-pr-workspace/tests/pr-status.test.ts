import {describe, expect, test} from "bun:test";
import {formatSidebarTokens, parsePullRequest} from "../src/pr-status";

function pullRequest(overrides: Readonly<Record<string, unknown>> = {}): unknown {
  return {
    number: 9561,
    state: "OPEN",
    isDraft: false,
    mergeable: "MERGEABLE",
    mergeStateStatus: "CLEAN",
    reviewDecision: "APPROVED",
    statusCheckRollup: [],
    ...overrides,
  };
}

describe("parsePullRequest", () => {
  test("parses the GitHub fields used by the sidebar", () => {
    const result = parsePullRequest(pullRequest());

    expect(result._tag).toBe("ok");
    if (result._tag === "err") return;
    expect(result.value.number).toBe(9561);
  });

  test("rejects malformed check data", () => {
    const result = parsePullRequest(pullRequest({statusCheckRollup: null}));

    expect(result._tag).toBe("err");
    if (result._tag === "ok") return;
    expect(result.error.field).toBe("statusCheckRollup");
  });
});

describe("formatSidebarTokens", () => {
  test("shows a mergeable PR with passing CI and approval", () => {
    const parsed = parsePullRequest(
      pullRequest({
        statusCheckRollup: [
          {__typename: "CheckRun", status: "COMPLETED", conclusion: "SUCCESS"},
          {__typename: "StatusContext", state: "SUCCESS"},
        ],
      }),
    );
    if (parsed._tag === "err") throw parsed.error;

    expect(formatSidebarTokens(parsed.value)).toEqual({
      pr: "#9561",
      merge: "mergeable",
      ci: "CI ✓",
      review: "review ✓",
    });
  });

  test("gives failed checks precedence over pending checks", () => {
    const parsed = parsePullRequest(
      pullRequest({
        mergeStateStatus: "BLOCKED",
        reviewDecision: "REVIEW_REQUIRED",
        statusCheckRollup: [
          {__typename: "CheckRun", status: "IN_PROGRESS", conclusion: ""},
          {__typename: "CheckRun", status: "COMPLETED", conclusion: "FAILURE"},
        ],
      }),
    );
    if (parsed._tag === "err") throw parsed.error;

    expect(formatSidebarTokens(parsed.value)).toEqual({
      pr: "#9561",
      merge: "blocked",
      ci: "CI ✗",
      review: "review needed",
    });
  });

  test("shows conflicts and omits an absent review decision", () => {
    const parsed = parsePullRequest(
      pullRequest({
        mergeable: "CONFLICTING",
        mergeStateStatus: "DIRTY",
        reviewDecision: "",
      }),
    );
    if (parsed._tag === "err") throw parsed.error;

    expect(formatSidebarTokens(parsed.value)).toEqual({
      pr: "#9561",
      merge: "conflicts",
      ci: "CI —",
    });
  });
});
