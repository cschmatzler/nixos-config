import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const EXECUTE_TOOL = "executor_execute";
const RESUME_TOOL = "executor_resume";
const APPROVAL_ENTRY = "executor-resume-approval";

const APPROVAL_REQUIRED_REASON =
  "BLOCKED: executor_resume requires explicit user approval after executor_execute pauses. " +
  "Wait for the user to send a message containing exactly `approve` before calling executor_resume.";

const UNKNOWN_EXECUTION_REASON =
  "BLOCKED: executor_resume may only use an executionId returned by an earlier " +
  "executor_execute result on the active session branch.";

type SessionBranch = ReturnType<ExtensionContext["sessionManager"]["getBranch"]>;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseToolResultText(text: string): unknown | undefined {
  try {
    return JSON.parse(text);
  } catch {
    // MCP tools without structured output may return plain text instead of JSON.
    return undefined;
  }
}

function collectExecutionIds(
  value: unknown,
  executionIds: Set<string>,
  visited: WeakSet<object>,
): void {
  if (Array.isArray(value)) {
    if (visited.has(value)) return;
    visited.add(value);
    for (const item of value) collectExecutionIds(item, executionIds, visited);
    return;
  }

  if (!isRecord(value)) return;
  if (visited.has(value)) return;
  visited.add(value);

  if (typeof value.executionId === "string" && value.executionId.length > 0) {
    executionIds.add(value.executionId);
  }

  if (value.type === "text" && typeof value.text === "string") {
    const parsed = parseToolResultText(value.text);
    if (parsed !== undefined) collectExecutionIds(parsed, executionIds, visited);
  }

  for (const nested of Object.values(value)) {
    collectExecutionIds(nested, executionIds, visited);
  }
}

function executionIdsFromExecuteResult(message: unknown): ReadonlySet<string> {
  const executionIds = new Set<string>();
  collectExecutionIds(message, executionIds, new WeakSet<object>());
  return executionIds;
}

function latestPausedExecutionId(branch: SessionBranch): string | undefined {
  for (let index = branch.length - 1; index >= 0; index -= 1) {
    const entry = branch[index];
    if (entry?.type !== "message") continue;
    if (entry.message.role !== "toolResult" || entry.message.toolName !== EXECUTE_TOOL) continue;

    const executionId = executionIdsFromExecuteResult(entry.message).values().next().value;
    if (typeof executionId === "string") return executionId;
  }

  return undefined;
}

function latestMatchingExecuteIndex(branch: SessionBranch, executionId: string): number | undefined {
  for (let index = branch.length - 1; index >= 0; index -= 1) {
    const entry = branch[index];
    if (entry?.type !== "message") continue;
    if (entry.message.role !== "toolResult" || entry.message.toolName !== EXECUTE_TOOL) continue;
    if (executionIdsFromExecuteResult(entry.message).has(executionId)) return index;
  }

  return undefined;
}

function isMatchingApprovalEntry(entry: SessionBranch[number], executionId: string): boolean {
  if (entry.type !== "custom" || entry.customType !== APPROVAL_ENTRY || !isRecord(entry.data)) {
    return false;
  }

  return entry.data.executionId === executionId;
}

function isApproveUserMessage(entry: SessionBranch[number]): boolean {
  if (entry.type !== "message" || entry.message.role !== "user") return false;

  const { content } = entry.message;
  if (typeof content === "string") return content.trim() === "approve";
  if (!Array.isArray(content)) return false;

  const text: string[] = [];
  for (const part of content) {
    if (!isRecord(part) || part.type !== "text" || typeof part.text !== "string") return false;
    text.push(part.text);
  }

  return text.join("").trim() === "approve";
}

function hasApprovalAfterExecute(
  branch: SessionBranch,
  executeIndex: number,
  executionId: string,
): boolean {
  let hasInputAttestation = false;

  for (const entry of branch.slice(executeIndex + 1)) {
    if (isMatchingApprovalEntry(entry, executionId)) {
      hasInputAttestation = true;
      continue;
    }

    if (hasInputAttestation && isApproveUserMessage(entry)) return true;
  }

  return false;
}

/** Prevents model-side Executor resumes until the user explicitly approves the paused execution. */
export default function executorResumeApproval(pi: ExtensionAPI) {
  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive" && event.source !== "rpc") return;
    if (event.text.trim() !== "approve" || (event.images?.length ?? 0) > 0) return;

    const executionId = latestPausedExecutionId(ctx.sessionManager.getBranch());
    if (!executionId) return;

    pi.appendEntry(APPROVAL_ENTRY, { executionId });
  });

  pi.on("tool_call", (event, ctx) => {
    if (event.toolName !== RESUME_TOOL) return;
    if (!isRecord(event.input) || typeof event.input.executionId !== "string") {
      return { block: true, reason: UNKNOWN_EXECUTION_REASON };
    }

    const branch = ctx.sessionManager.getBranch();
    const executeIndex = latestMatchingExecuteIndex(branch, event.input.executionId);
    if (executeIndex === undefined) {
      return { block: true, reason: UNKNOWN_EXECUTION_REASON };
    }

    if (!hasApprovalAfterExecute(branch, executeIndex, event.input.executionId)) {
      return { block: true, reason: APPROVAL_REQUIRED_REASON };
    }
  });
}
