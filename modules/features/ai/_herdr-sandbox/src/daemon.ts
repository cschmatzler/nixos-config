import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { timingSafeEqual } from "node:crypto";

import { startEgressGate, type AllowedEndpoint } from "./egress";
import {
  authorize,
  call,
  demotePrivilegedReportSource,
  filterResponse,
  HerdrError,
  scopeFromSnapshot,
  snapshot,
  type RpcRequest,
} from "./herdr";

const MAX_BODY_BYTES = 1024 * 1024;

type BrokerConfig = {
  readonly herdrSocketPath: string;
  readonly stateDirectory: string;
  readonly listenPort: number;
  readonly egressPort: number;
  readonly proxyPort: number;
  readonly proxyTokenFile: string;
  readonly credentialToken: string;
  readonly credentialPaths: ReadonlyArray<string>;
  readonly allowedEndpoints: ReadonlyArray<AllowedEndpoint>;
};

type Registration = {
  readonly workspaceId: string;
  readonly sandboxName: string;
  readonly checkoutPath: string;
  readonly token: string;
};

class BodyTooLarge extends Error {}

function readConfig(): BrokerConfig {
  const flag = process.argv.indexOf("--config");
  const configPath = flag === -1 ? undefined : process.argv[flag + 1];
  if (configPath === undefined) throw new Error("usage: --config PATH");
  return JSON.parse(fs.readFileSync(configPath, "utf8"));
}

const config = readConfig();
const proxyToken = fs.readFileSync(config.proxyTokenFile, "utf8").trim();
if (!/^[a-f0-9]{64}$/.test(proxyToken)) {
  throw new Error("invalid egress proxy token");
}

function readRegistration(registrationPath: string): Registration | undefined {
  try {
    // SAFETY: The host dispatcher writes registrations atomically with this exact shape.
    return JSON.parse(fs.readFileSync(registrationPath, "utf8")) as Registration;
  } catch {
    return undefined;
  }
}

function tokensEqual(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  return leftBytes.length === rightBytes.length && timingSafeEqual(leftBytes, rightBytes);
}

function registrationForToken(token: string): Registration | undefined {
  const directory = path.join(config.stateDirectory, "registrations");
  if (!fs.existsSync(directory)) return undefined;
  for (const entry of fs.readdirSync(directory)) {
    if (!entry.endsWith(".json")) continue;
    const registration = readRegistration(path.join(directory, entry));
    if (registration !== undefined && tokensEqual(token, registration.token)) {
      return registration;
    }
  }
  return undefined;
}

function sendJson(response: http.ServerResponse, status: number, body: unknown): void {
  response.writeHead(status, { "content-type": "application/json" });
  response.end(JSON.stringify(body));
}

async function readBody(request: http.IncomingMessage): Promise<string> {
  let body = "";
  let size = 0;
  for await (const chunk of request) {
    size += Buffer.byteLength(chunk);
    if (size > MAX_BODY_BYTES) {
      request.destroy();
      throw new BodyTooLarge();
    }
    body += chunk;
  }
  return body;
}

async function handleRpc(request: http.IncomingMessage, response: http.ServerResponse): Promise<void> {
  const authorization = request.headers.authorization;
  const token = authorization?.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : undefined;
  const registration = token === undefined ? undefined : registrationForToken(token);
  if (registration === undefined) {
    sendJson(response, 401, { error: "invalid capability" });
    return;
  }

  const scope = scopeFromSnapshot(
    await snapshot(config.herdrSocketPath),
    registration.workspaceId,
  );
  if (scope === undefined || scope.checkoutPath !== registration.checkoutPath) {
    sendJson(response, 403, { error: "workspace is no longer live" });
    return;
  }

  let rpcRequest: RpcRequest;
  try {
    rpcRequest = JSON.parse(await readBody(request));
  } catch (cause: unknown) {
    sendJson(
      response,
      cause instanceof BodyTooLarge ? 413 : 400,
      { error: cause instanceof BodyTooLarge ? "request exceeds one MiB" : "invalid request body" },
    );
    return;
  }

  const denied = authorize(rpcRequest, scope);
  if (denied !== undefined) {
    sendJson(response, 403, { error: denied });
    return;
  }
  demotePrivilegedReportSource(rpcRequest);
  let result: unknown;
  try {
    result = await call(config.herdrSocketPath, rpcRequest.method, rpcRequest.params);
  } catch (cause: unknown) {
    if (cause instanceof HerdrError) {
      sendJson(response, 200, { id: rpcRequest.id, error: cause.body });
      return;
    }
    throw cause;
  }
  sendJson(response, 200, {
    id: rpcRequest.id,
    result: filterResponse(result, registration.workspaceId, rpcRequest.method),
  });
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
    const message = cause instanceof Error ? cause.message : String(cause);
    console.error(`[herdr-sandbox] broker request failed: ${message}`);
    if (!response.headersSent) sendJson(response, 500, { error: "bridge request failed" });
  });
});

const egressGate = startEgressGate({
  listenHost: "127.0.0.1",
  listenPort: config.egressPort,
  proxyHost: "127.0.0.1",
  proxyPort: config.proxyPort,
  proxyToken,
  credentialToken: config.credentialToken,
  credentialPaths: config.credentialPaths,
  allowedEndpoints: config.allowedEndpoints,
});
egressGate.on("listening", () => {
  console.log(`[herdr-sandbox] egress gate ready on 127.0.0.1:${config.egressPort}`);
});
egressGate.on("error", (cause: Error) => {
  console.error(`[herdr-sandbox] egress gate failed: ${cause.message}`);
  process.exitCode = 1;
  server.close();
});

server.listen(config.listenPort, "127.0.0.1", () => {
  console.log(`[herdr-sandbox] broker ready on 127.0.0.1:${config.listenPort}`);
});
