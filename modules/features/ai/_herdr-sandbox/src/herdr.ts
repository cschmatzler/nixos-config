import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { randomUUID } from "node:crypto";

import { timeoutForMethod } from "./common";

type Json = Record<string, unknown>;

export async function call(socketPath: string, method: string, params: Json = {}): Promise<any> {
  const request = { id: `herdr-sandbox:${randomUUID()}`, method, params };
  const line: string = await new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error(`herdr ${method} timed out`));
    }, timeoutForMethod(method));
    let buffered = "";
    socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
    socket.on("data", (chunk) => {
      buffered += chunk.toString("utf8");
      const newline = buffered.indexOf("\n");
      if (newline === -1) return;
      clearTimeout(timeout);
      socket.destroy();
      resolve(buffered.slice(0, newline));
    });
    socket.on("error", (cause) => {
      clearTimeout(timeout);
      reject(cause);
    });
  });
  const response = JSON.parse(line);
  if (response.error) throw new Error(`herdr ${method}: ${response.error.message ?? "error"}`);
  return response.result;
}

export async function snapshot(socketPath: string): Promise<any> {
  return (await call(socketPath, "session.snapshot")).snapshot;
}

export type Scope = {
  readonly workspaceId: string;
  readonly checkoutPath: string;
  readonly tabIds: ReadonlySet<string>;
  readonly paneIds: ReadonlySet<string>;
  readonly agentNames: ReadonlySet<string>;
};

export function scopeFromSnapshot(snap: any, workspaceId: string): Scope | undefined {
  const workspace = snap.workspaces?.find((candidate: any) =>
    candidate.workspace_id === workspaceId
  );
  if (typeof workspace?.worktree?.checkout_path !== "string") return undefined;
  const tabIds = new Set<string>();
  for (const tab of snap.tabs ?? []) {
    if (tab.workspace_id === workspaceId && typeof tab.tab_id === "string") {
      tabIds.add(tab.tab_id);
    }
  }
  const paneIds = new Set<string>();
  for (const pane of snap.panes ?? []) {
    if (pane.workspace_id === workspaceId && typeof pane.pane_id === "string") {
      paneIds.add(pane.pane_id);
    }
  }
  const agentNames = new Set<string>();
  for (const agent of snap.agents ?? []) {
    if (agent.workspace_id === workspaceId && typeof agent.name === "string") {
      agentNames.add(agent.name);
    }
  }
  return {
    workspaceId,
    checkoutPath: fs.realpathSync(workspace.worktree.checkout_path),
    tabIds,
    paneIds,
    agentNames,
  };
}

const ALLOWED_METHODS = new Set([
  "ping", "session.snapshot",
  "workspace.list", "workspace.get", "workspace.focus", "workspace.report_metadata",
  "tab.list", "tab.get", "tab.create", "tab.focus", "tab.rename", "tab.close",
  "pane.list", "pane.current", "pane.get", "pane.layout", "pane.process_info",
  "pane.neighbor", "pane.edges", "pane.read", "pane.wait_for_output",
  "pane.split", "pane.zoom", "pane.focus_direction", "pane.resize", "pane.rename",
  "pane.send_text", "pane.send_keys", "pane.send_input", "pane.report_agent",
  "pane.report_agent_session", "pane.report_metadata", "pane.clear_agent_authority",
  "pane.release_agent", "pane.close",
  "agent.list", "agent.get", "agent.read", "agent.explain", "agent.wait",
  "agent.start", "agent.prompt", "agent.send_keys", "agent.rename", "agent.focus",
  "notification.show",
]);

const EXPLICIT_PANE_METHODS = new Set([
  "pane.current", "pane.layout", "pane.process_info", "pane.neighbor", "pane.edges",
  "pane.zoom", "pane.focus_direction", "pane.resize",
]);

function identifiersInScope(value: unknown, scope: Scope, key?: string): boolean {
  if (typeof value === "string") {
    if (key === "workspace_id") return value === scope.workspaceId;
    if (key === "tab_id") return scope.tabIds.has(value);
    if (key === "pane_id" || key === "target_pane_id" || key === "caller_pane_id") {
      return scope.paneIds.has(value);
    }
    if (key === "target") return scope.paneIds.has(value) || scope.agentNames.has(value);
    return true;
  }
  if (Array.isArray(value)) return value.every((entry) => identifiersInScope(entry, scope, key));
  if (typeof value !== "object" || value === null) return true;
  return Object.entries(value).every(([nestedKey, entry]) =>
    identifiersInScope(entry, scope, nestedKey)
  );
}

function physicalPathWithin(root: string, candidate: unknown): boolean {
  if (typeof candidate !== "string") return false;
  try {
    const physical = fs.realpathSync(candidate);
    const relative = path.relative(root, physical);
    return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== "..");
  } catch {
    return false;
  }
}

function sanitizeLaunch(request: any, scope: Scope): string | undefined {
  if (request.method !== "pane.split" && request.method !== "tab.create") return undefined;
  delete request.params.env;
  request.params.workspace_id = scope.workspaceId;
  if (request.params.cwd !== undefined && !physicalPathWithin(scope.checkoutPath, request.params.cwd)) {
    return "cwd is outside the workspace";
  }
  return undefined;
}

function hasExplicitPaneTarget(request: any): boolean {
  if (request.method === "pane.current") return typeof request.params.caller_pane_id === "string";
  return typeof request.params.pane_id === "string";
}

export function authorize(request: any, scope: Scope): string | undefined {
  if (
    typeof request?.method !== "string" ||
    typeof request?.params !== "object" ||
    request.params === null ||
    Array.isArray(request.params)
  ) {
    return "invalid request envelope";
  }
  if (!ALLOWED_METHODS.has(request.method)) return `method ${request.method} is not available`;
  const unsafeLaunch = sanitizeLaunch(request, scope);
  if (unsafeLaunch !== undefined) return unsafeLaunch;
  if (EXPLICIT_PANE_METHODS.has(request.method) && !hasExplicitPaneTarget(request)) {
    return "explicit pane target required";
  }
  if (!identifiersInScope(request.params, scope)) return "target is outside the workspace";
  return undefined;
}

// Herdr shelves reports from "herdr:*" sources until its host-side process
// detection sees the agent, which never happens for processes inside the VM.
export function demotePrivilegedReportSource(request: any): void {
  if (
    typeof request?.method === "string" &&
    request.method.startsWith("pane.report_") &&
    typeof request.params?.source === "string" &&
    request.params.source.startsWith("herdr:")
  ) {
    request.params.source = `sandbox:${request.params.source.slice("herdr:".length)}`;
  }
}

const FILTERED = Symbol("filtered");

function filterValue(value: unknown, workspaceId: string): unknown {
  if (Array.isArray(value)) {
    return value.map((entry) => filterValue(entry, workspaceId)).filter((v) => v !== FILTERED);
  }
  if (typeof value !== "object" || value === null) return value;
  const record = value as Record<string, unknown>;
  if (typeof record.workspace_id === "string" && record.workspace_id !== workspaceId) {
    return FILTERED;
  }
  const filtered: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(record)) {
    const result = filterValue(entry, workspaceId);
    if (result !== FILTERED) filtered[key] = result;
  }
  return filtered;
}

export function filterResponse(value: unknown, workspaceId: string): unknown {
  const filtered = filterValue(value, workspaceId);
  return filtered === FILTERED ? {} : filtered;
}
