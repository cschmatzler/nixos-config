import net from "node:net";
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
  readonly paneIds: ReadonlySet<string>;
  readonly agentNames: ReadonlySet<string>;
};

export function scopeFromSnapshot(snap: any, workspaceId: string): Scope | undefined {
  if (!snap.workspaces?.some((w: any) => w.workspace_id === workspaceId)) return undefined;
  const paneIds = new Set<string>();
  for (const pane of snap.panes ?? []) {
    if (pane.workspace_id === workspaceId) paneIds.add(pane.pane_id);
  }
  const agentNames = new Set<string>();
  for (const agent of snap.agents ?? []) {
    if (agent.workspace_id === workspaceId && typeof agent.name === "string") {
      agentNames.add(agent.name);
    }
  }
  return { workspaceId, paneIds, agentNames };
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
  "agent.view.set", "agent.view.clear",
  "notification.show",
]);

function identifiersInScope(value: unknown, scope: Scope, key?: string): boolean {
  if (typeof value === "string") {
    const isId = key !== undefined && (key.endsWith("_id") || key === "target");
    if (!isId || !value.startsWith("w")) return true;
    const colon = value.indexOf(":");
    if (colon === -1) return value === scope.workspaceId || scope.agentNames.has(value);
    if (!value.startsWith(`${scope.workspaceId}:`)) return false;
    const isPaneRef = value.slice(colon + 1).startsWith("p");
    return !isPaneRef || scope.paneIds.has(value) || scope.agentNames.has(value);
  }
  if (Array.isArray(value)) return value.every((entry) => identifiersInScope(entry, scope, key));
  if (typeof value !== "object" || value === null) return true;
  return Object.entries(value).every(([k, entry]) => identifiersInScope(entry, scope, k));
}

export function authorize(request: any, scope: Scope): string | undefined {
  if (typeof request?.method !== "string" || typeof request?.params !== "object") {
    return "invalid request envelope";
  }
  if (!ALLOWED_METHODS.has(request.method)) return `method ${request.method} is not available`;
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
