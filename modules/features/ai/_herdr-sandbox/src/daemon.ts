import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { timingSafeEqual } from "node:crypto";

import { causeMessage, readConfig } from "./common";
import {
  authorize,
  call,
  demotePrivilegedReportSource,
  filterResponse,
  scopeFromSnapshot,
  snapshot,
} from "./herdr";

const MAX_BODY_BYTES = 1024 * 1024;
const config = readConfig();

type Registration = {
  readonly workspaceId: string;
  readonly sandboxName: string;
  readonly checkoutPath: string;
  readonly token: string;
};

type RpcRequest = {
  readonly id: string;
  readonly method: string;
  readonly params: Record<string, unknown>;
};

class BodyTooLarge extends Error {}

function readRegistration(registrationPath: string): Registration | undefined {
  try {
    // Registrations are written atomically by the trusted host dispatcher.
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
  const result = await call(config.herdrSocketPath, rpcRequest.method, rpcRequest.params);
  sendJson(response, 200, {
    id: rpcRequest.id,
    result: filterResponse(result, registration.workspaceId),
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
    console.error(`[herdr-sandbox] broker request failed: ${causeMessage(cause)}`);
    if (!response.headersSent) sendJson(response, 500, { error: "bridge request failed" });
  });
});

server.listen(config.listenPort, "127.0.0.1", () => {
  console.log(`[herdr-sandbox] broker ready on 127.0.0.1:${config.listenPort}`);
});
