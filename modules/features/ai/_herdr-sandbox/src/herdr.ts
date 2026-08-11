import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { randomUUID } from "node:crypto";

import { timeoutForMethod } from "./rpc";

/** RPC request accepted from a sandbox relay. */
export type RpcRequest = {
  readonly id: string;
  readonly method: string;
  readonly params: Record<string, unknown>;
};

type Worktree = {
  readonly checkout_path: string;
};

type Workspace = {
  readonly workspace_id: string;
  readonly worktree?: Worktree;
};

type Tab = {
  readonly tab_id: string;
  readonly workspace_id: string;
};

type Pane = {
  readonly pane_id: string;
  readonly workspace_id: string;
};

type Agent = {
  readonly name?: string;
  readonly workspace_id: string;
};

type SessionSnapshot = {
  readonly focused_workspace_id?: string;
  readonly focused_tab_id?: string;
  readonly focused_pane_id?: string;
  readonly workspaces: ReadonlyArray<Workspace>;
  readonly tabs: ReadonlyArray<Tab>;
  readonly panes: ReadonlyArray<Pane>;
  readonly layouts: ReadonlyArray<{ readonly workspace_id: string }>;
  readonly agents: ReadonlyArray<Agent>;
};

type HerdrErrorBody = { readonly code?: string; readonly message?: string };

type HerdrResponse<T> = {
  readonly result: T;
  readonly error?: HerdrErrorBody;
};

/** Error response returned by the Herdr host for a well-formed request. */
export class HerdrError extends Error {
  constructor(readonly body: HerdrErrorBody) {
    super(body.message ?? "herdr error");
  }
}

type WorkspaceListResult = { readonly workspaces: ReadonlyArray<Workspace> };
type TabListResult = { readonly tabs: ReadonlyArray<Tab> };
type PaneListResult = { readonly panes: ReadonlyArray<Pane> };
type AgentListResult = { readonly agents: ReadonlyArray<Agent> };
type SnapshotResult = { readonly snapshot: SessionSnapshot };

/** Live Herdr resources granted to one sandbox. */
export type Scope = {
  readonly workspaceId: string;
  readonly checkoutPath: string;
  readonly tabIds: ReadonlySet<string>;
  readonly paneIds: ReadonlySet<string>;
  readonly agentNames: ReadonlySet<string>;
};

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

const WORKSPACE_TARGET_METHODS = new Set([
  "workspace.get", "workspace.focus", "workspace.report_metadata",
]);
const TAB_TARGET_METHODS = new Set([
  "tab.get", "tab.focus", "tab.rename", "tab.close",
]);
const PANE_TARGET_METHODS = new Set([
  "pane.get", "pane.read", "pane.wait_for_output", "pane.rename", "pane.send_text",
  "pane.send_keys", "pane.send_input", "pane.report_agent", "pane.report_agent_session",
  "pane.report_metadata", "pane.clear_agent_authority", "pane.release_agent", "pane.close",
]);
const OPTIONAL_PANE_METHODS = new Set([
  "pane.layout", "pane.process_info", "pane.neighbor", "pane.edges", "pane.zoom",
  "pane.focus_direction", "pane.resize",
]);
const AGENT_TARGET_METHODS = new Set([
  "agent.get", "agent.read", "agent.explain", "agent.wait", "agent.prompt",
  "agent.send_keys", "agent.rename", "agent.focus",
]);

/** Send one request to the host Herdr socket. */
export async function call(
  socketPath: string,
  method: string,
  params: Record<string, unknown> = {},
): Promise<unknown> {
  const request = { id: `herdr-sandbox:${randomUUID()}`, method, params };
  const line = await new Promise<string>((resolve, reject) => {
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
  const response: HerdrResponse<unknown> = JSON.parse(line);
  if (response.error !== undefined) {
    throw new HerdrError(response.error);
  }
  return response.result;
}

/** Read the live topology used to derive sandbox authority. */
export async function snapshot(socketPath: string): Promise<SessionSnapshot> {
  const result = await call(socketPath, "session.snapshot");
  // SAFETY: This response comes from the pinned Herdr host process and is consumed immediately.
  return (result as SnapshotResult).snapshot;
}

/** Derive one workspace's live authority from a Herdr snapshot. */
export function scopeFromSnapshot(
  session: SessionSnapshot,
  workspaceId: string,
): Scope | undefined {
  const workspace = session.workspaces.find((candidate) =>
    candidate.workspace_id === workspaceId
  );
  if (workspace?.worktree === undefined) return undefined;
  return {
    workspaceId,
    checkoutPath: fs.realpathSync(workspace.worktree.checkout_path),
    tabIds: new Set(
      session.tabs
        .filter((tab) => tab.workspace_id === workspaceId)
        .map((tab) => tab.tab_id),
    ),
    paneIds: new Set(
      session.panes
        .filter((pane) => pane.workspace_id === workspaceId)
        .map((pane) => pane.pane_id),
    ),
    agentNames: new Set(
      session.agents
        .filter((agent) => agent.workspace_id === workspaceId)
        .flatMap((agent) => agent.name === undefined ? [] : [agent.name]),
    ),
  };
}

function pathIsWithin(root: string, candidate: string): boolean {
  try {
    const relative = path.relative(root, fs.realpathSync(candidate));
    return relative === "" || (relative !== ".." && !relative.startsWith(`..${path.sep}`));
  } catch {
    return false;
  }
}

/** Apply the workspace capability policy and remove unsafe launch parameters. */
export function authorize(request: RpcRequest, scope: Scope): string | undefined {
  if (!ALLOWED_METHODS.has(request.method)) return `method ${request.method} is not available`;

  if (request.method === "pane.split" || request.method === "tab.create") {
    delete request.params.env;
    request.params.workspace_id = scope.workspaceId;
    const cwd = request.params.cwd;
    if (cwd !== undefined && !pathIsWithin(scope.checkoutPath, String(cwd))) {
      return "cwd is outside the workspace";
    }
    const targetPane = request.params.target_pane_id;
    if (targetPane !== undefined && !scope.paneIds.has(String(targetPane))) {
      return "target is outside the workspace";
    }
  }

  if (
    WORKSPACE_TARGET_METHODS.has(request.method) &&
    request.params.workspace_id !== scope.workspaceId
  ) {
    return "target is outside the workspace";
  }
  if (
    TAB_TARGET_METHODS.has(request.method) &&
    !scope.tabIds.has(String(request.params.tab_id))
  ) {
    return "target is outside the workspace";
  }
  if (
    PANE_TARGET_METHODS.has(request.method) &&
    !scope.paneIds.has(String(request.params.pane_id))
  ) {
    return "target is outside the workspace";
  }
  if (
    OPTIONAL_PANE_METHODS.has(request.method) &&
    !scope.paneIds.has(String(request.params.pane_id))
  ) {
    return "explicit pane target required";
  }
  if (
    request.method === "pane.current" &&
    !scope.paneIds.has(String(request.params.caller_pane_id))
  ) {
    return "explicit pane target required";
  }
  if (
    request.method === "agent.start" &&
    !scope.paneIds.has(String(request.params.pane_id))
  ) {
    return "target is outside the workspace";
  }
  if (
    AGENT_TARGET_METHODS.has(request.method) &&
    !scope.paneIds.has(String(request.params.target)) &&
    !scope.agentNames.has(String(request.params.target))
  ) {
    return "target is outside the workspace";
  }
  return undefined;
}

/** Demote host-only report sources emitted by agents running inside the sandbox. */
export function demotePrivilegedReportSource(request: RpcRequest): void {
  if (
    !request.method.startsWith("pane.report_") &&
    request.method !== "workspace.report_metadata"
  ) {
    return;
  }
  for (const key of ["source", "applies_to_source"]) {
    const value = request.params[key];
    if (typeof value === "string" && value.startsWith("herdr:")) {
      request.params[key] = `sandbox:${value.slice("herdr:".length)}`;
    }
  }
}

/** Remove cross-workspace entries from global list and snapshot responses. */
export function filterResponse(
  value: unknown,
  workspaceId: string,
  method: string,
): unknown {
  // SAFETY: Herdr result shapes are pinned by the flake and selected by the method name.
  if (method === "workspace.list") {
    const result = value as WorkspaceListResult;
    return {
      ...result,
      workspaces: result.workspaces.filter((entry) => entry.workspace_id === workspaceId),
    };
  }
  if (method === "tab.list") {
    const result = value as TabListResult;
    return { ...result, tabs: result.tabs.filter((entry) => entry.workspace_id === workspaceId) };
  }
  if (method === "pane.list") {
    const result = value as PaneListResult;
    return { ...result, panes: result.panes.filter((entry) => entry.workspace_id === workspaceId) };
  }
  if (method === "agent.list") {
    const result = value as AgentListResult;
    return { ...result, agents: result.agents.filter((entry) => entry.workspace_id === workspaceId) };
  }
  if (method === "session.snapshot") {
    const result = value as SnapshotResult;
    const tabs = result.snapshot.tabs.filter((entry) => entry.workspace_id === workspaceId);
    const panes = result.snapshot.panes.filter((entry) => entry.workspace_id === workspaceId);
    const tabIds = new Set(tabs.map((entry) => entry.tab_id));
    const paneIds = new Set(panes.map((entry) => entry.pane_id));
    return {
      snapshot: {
        ...result.snapshot,
        focused_workspace_id: result.snapshot.focused_workspace_id === workspaceId
          ? workspaceId
          : undefined,
        focused_tab_id: tabIds.has(result.snapshot.focused_tab_id ?? "")
          ? result.snapshot.focused_tab_id
          : undefined,
        focused_pane_id: paneIds.has(result.snapshot.focused_pane_id ?? "")
          ? result.snapshot.focused_pane_id
          : undefined,
        workspaces: result.snapshot.workspaces.filter((entry) => entry.workspace_id === workspaceId),
        tabs,
        panes,
        layouts: result.snapshot.layouts.filter((entry) => entry.workspace_id === workspaceId),
        agents: result.snapshot.agents.filter((entry) => entry.workspace_id === workspaceId),
      },
    };
  }
  return value;
}
