import net from "node:net";
import { randomUUID } from "node:crypto";

const LONG_METHODS = new Set(["agent.prompt", "agent.wait", "pane.wait_for_output"]);

type Json = Record<string, unknown>;

export async function call(socketPath: string, method: string, params: Json = {}): Promise<any> {
  const request = { id: `herdr-sandbox:${randomUUID()}`, method, params };
  const line: string = await new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error(`herdr ${method} timed out`));
    }, LONG_METHODS.has(method) ? 305_000 : 5_000);
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
    if (value.includes(":")) {
      if (!value.startsWith(`${scope.workspaceId}:`)) return false;
      return !value.includes(":p") || scope.paneIds.has(value) || scope.agentNames.has(value);
    }
    return value === scope.workspaceId || scope.agentNames.has(value);
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

export function filterResponse(value: unknown, workspaceId: string): unknown {
  if (Array.isArray(value)) {
    return value
      .filter((entry: any) => entry?.workspace_id === undefined || entry.workspace_id === workspaceId)
      .map((entry) => filterResponse(entry, workspaceId));
  }
  if (typeof value !== "object" || value === null) return value;
  return Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [key, filterResponse(entry, workspaceId)]),
  );
}
