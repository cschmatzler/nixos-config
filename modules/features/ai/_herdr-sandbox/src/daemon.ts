import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { randomBytes } from "node:crypto";

import {
  listSandboxes,
  mappingsDirectory,
  readConfig,
  run,
  tokenSecretPath,
  verifyWorkspaceToken,
} from "./common";
import {
  authorize,
  call,
  demotePrivilegedReportSource,
  filterResponse,
  scopeFromSnapshot,
  snapshot,
} from "./herdr";

const config = readConfig();

function loadTokenSecret(): string {
  fs.mkdirSync(config.stateDirectory, { recursive: true, mode: 0o700 });
  const secretPath = tokenSecretPath(config);
  if (!fs.existsSync(secretPath)) {
    fs.writeFileSync(secretPath, randomBytes(32).toString("hex"), { mode: 0o600, flag: "wx" });
  }
  return fs.readFileSync(secretPath, "utf8").trim();
}

const tokenSecret = loadTokenSecret();

function sendJson(response: http.ServerResponse, status: number, body: unknown): void {
  const encoded = JSON.stringify(body);
  response.writeHead(status, { "content-type": "application/json" });
  response.end(encoded);
}

async function readBody(request: http.IncomingMessage): Promise<string> {
  let body = "";
  for await (const chunk of request) body += chunk;
  return body;
}

async function handleRpc(request: http.IncomingMessage, response: http.ServerResponse): Promise<void> {
  const token = request.headers.authorization?.replace(/^Bearer /, "");
  const workspaceId = token === undefined ? undefined : verifyWorkspaceToken(token, tokenSecret);
  if (workspaceId === undefined) {
    sendJson(response, 401, { error: "invalid capability" });
    return;
  }
  const scope = scopeFromSnapshot(await snapshot(config.herdrSocketPath), workspaceId);
  if (scope === undefined) {
    sendJson(response, 403, { error: "workspace is no longer live" });
    return;
  }
  const body = JSON.parse(await readBody(request));
  const denied = authorize(body, scope);
  if (denied !== undefined) {
    sendJson(response, 403, { error: denied });
    return;
  }
  demotePrivilegedReportSource(body);
  const result = await call(config.herdrSocketPath, body.method, body.params);
  sendJson(response, 200, { id: body.id, result: filterResponse(result, workspaceId) });
}

const server = http.createServer((request, response) => {
  if (request.method === "GET" && request.url === "/health") {
    sendJson(response, 200, { status: "ok" });
    return;
  }
  if (request.method !== "POST" || request.url !== "/herdr/rpc") {
    sendJson(response, 404, { error: "not found" });
    return;
  }
  handleRpc(request, response).catch((cause: unknown) => {
    console.error("[herdr-sandbox] rpc failed", cause);
    if (!response.headersSent) sendJson(response, 500, { error: "bridge request failed" });
  });
});

type Mapping = { workspacePath: string; sandboxName: string };

function readMappings(): Array<{ file: string; mapping: Mapping }> {
  const directory = mappingsDirectory(config);
  if (!fs.existsSync(directory)) return [];
  return fs
    .readdirSync(directory)
    .filter((entry) => entry.endsWith(".json"))
    .map((entry) => {
      const file = path.join(directory, entry);
      return { file, mapping: JSON.parse(fs.readFileSync(file, "utf8")) as Mapping };
    });
}

const lastActive = new Map<string, number>();

async function reconcile(): Promise<void> {
  const mappings = readMappings();
  if (mappings.length === 0) return;
  const sandboxes = await listSandboxes(config);
  let snap: any = null;
  try {
    snap = await snapshot(config.herdrSocketPath);
  } catch {
    snap = null;
  }

  for (const { file, mapping } of mappings) {
    const state = sandboxes.get(mapping.sandboxName);
    if (state === undefined) {
      fs.rmSync(file, { force: true });
      lastActive.delete(mapping.sandboxName);
      continue;
    }
    const workspace = snap?.workspaces?.find(
      (w: any) => w.worktree?.checkout_path === mapping.workspacePath,
    );
    if (snap !== null && workspace === undefined) {
      console.log(`[herdr-sandbox] removing ${mapping.sandboxName} (workspace closed)`);
      await run(config.sbxPath, ["rm", "--force", mapping.sandboxName]);
      fs.rmSync(file, { force: true });
      lastActive.delete(mapping.sandboxName);
      continue;
    }
    const active =
      workspace !== undefined &&
      (snap.focused_workspace_id === workspace.workspace_id ||
        snap.agents?.some(
          (a: any) => a.workspace_id === workspace.workspace_id && a.agent_status === "working",
        ));
    const now = Date.now();
    if (active || !lastActive.has(mapping.sandboxName)) lastActive.set(mapping.sandboxName, now);
    const idleSince = lastActive.get(mapping.sandboxName) ?? now;
    if (!active && state === "running" && now - idleSince > config.idleMinutes * 60_000) {
      console.log(`[herdr-sandbox] pausing ${mapping.sandboxName} (idle)`);
      await run(config.sbxPath, ["stop", mapping.sandboxName]);
    }
  }
}

setInterval(() => {
  reconcile().catch((cause: unknown) => console.error("[herdr-sandbox] reconcile failed", cause));
}, 30_000);

server.listen(config.listenPort, "127.0.0.1", () => {
  console.log(`[herdr-sandbox] bridge ready on 127.0.0.1:${config.listenPort}`);
});
