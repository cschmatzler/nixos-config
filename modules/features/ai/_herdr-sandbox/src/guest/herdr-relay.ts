import fs from "node:fs";
import net from "node:net";

import { timeoutForMethod } from "../common";

const MAX_LINE_BYTES = 1024 * 1024;
const socketPath = process.env.HERDR_SOCKET_PATH;
const bridgeUrl = process.env.HERDR_SANDBOX_BRIDGE_URL;
const capability = process.env.HERDR_SANDBOX_TOKEN;

if (socketPath === undefined || bridgeUrl === undefined || capability === undefined) {
  console.error("herdr relay configuration is incomplete");
  process.exit(2);
}

function parseEnvelope(input: string): { id: string; timeout: number } {
  try {
    const parsed: any = JSON.parse(input);
    return {
      id: typeof parsed?.id === "string" ? parsed.id : "herdr-sandbox:invalid",
      timeout: timeoutForMethod(parsed?.method),
    };
  } catch {
    return { id: "herdr-sandbox:invalid", timeout: 5_000 };
  }
}

function errorEnvelope(id: string, message: string): string {
  return JSON.stringify({
    id,
    error: {
      code: "sandbox_bridge_unavailable",
      message,
    },
  });
}

async function forward(line: string): Promise<string> {
  const { id, timeout } = parseEnvelope(line);
  try {
    const response = await fetch(`${bridgeUrl}/herdr/rpc`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${capability}`,
        "content-type": "application/json",
      },
      body: line,
      signal: AbortSignal.timeout(timeout),
    });
    const body = await response.text();
    if (!response.ok) {
      return errorEnvelope(id, `sandbox bridge rejected request (${response.status})`);
    }
    JSON.parse(body);
    return body;
  } catch {
    return errorEnvelope(id, "sandbox bridge is unavailable");
  }
}

try {
  fs.rmSync(socketPath, { force: true });
} catch {
  // The server bind below reports an actionable failure when cleanup was insufficient.
}

const server = net.createServer((socket) => {
  let buffered = "";
  let queue = Promise.resolve();
  socket.on("error", () => socket.destroy());
  socket.setEncoding("utf8");
  socket.on("data", (chunk: string) => {
    buffered += chunk;
    if (Buffer.byteLength(buffered, "utf8") > MAX_LINE_BYTES) {
      socket.end(`${errorEnvelope("herdr-sandbox:oversized", "request exceeds one MiB")}\n`);
      return;
    }
    let newline = buffered.indexOf("\n");
    while (newline !== -1) {
      const line = buffered.slice(0, newline);
      buffered = buffered.slice(newline + 1);
      if (line.length > 0) {
        queue = queue.then(async () => {
          const response = await forward(line);
          if (!socket.destroyed) socket.write(`${response}\n`);
        });
      }
      newline = buffered.indexOf("\n");
    }
  });
});

server.on("error", () => {
  process.exitCode = 1;
});
server.listen(socketPath, () => {
  fs.chmodSync(socketPath, 0o600);
});

const shutdown = (): void => {
  server.close(() => process.exit(0));
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
