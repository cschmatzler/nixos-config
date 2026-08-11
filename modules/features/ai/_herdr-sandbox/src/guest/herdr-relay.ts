import fs from "node:fs";
import net from "node:net";

import { timeoutForMethod } from "../rpc";

const MAX_LINE_BYTES = 1024 * 1024;
const socketPath = process.env.HERDR_SOCKET_PATH;
const bridgeUrl = process.env.HERDR_SANDBOX_BRIDGE_URL;
const capability = process.env.HERDR_SANDBOX_TOKEN;

if (socketPath === undefined || bridgeUrl === undefined || capability === undefined || capability === "") {
  console.error("herdr relay configuration is incomplete");
  process.exit(2);
}

function parseEnvelope(input: string): { id: string; timeout: number } {
  try {
    const parsed: { readonly id?: unknown; readonly method?: unknown } = JSON.parse(input);
    return {
      id: String(parsed.id ?? "herdr-sandbox:invalid"),
      timeout: timeoutForMethod(String(parsed.method ?? "")),
    };
  } catch {
    return { id: "herdr-sandbox:invalid", timeout: 5_000 };
  }
}

function rejectionDetail(body: string): string {
  try {
    const parsed: { readonly error?: unknown } = JSON.parse(body);
    return typeof parsed.error === "string" ? `: ${parsed.error}` : "";
  } catch {
    return "";
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
      return errorEnvelope(id, `sandbox bridge rejected request (${response.status})${rejectionDetail(body)}`);
    }
    JSON.parse(body);
    return body;
  } catch {
    return errorEnvelope(id, "sandbox bridge is unavailable");
  }
}

fs.rmSync(socketPath, { force: true });

const server = net.createServer((socket) => {
  let buffered = "";
  let queue = Promise.resolve();
  socket.on("error", () => socket.destroy());
  socket.setEncoding("utf8");
  const onData = (chunk: string): void => {
    buffered += chunk;
    if (Buffer.byteLength(buffered, "utf8") > MAX_LINE_BYTES) {
      socket.off("data", onData);
      buffered = "";
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
  };
  socket.on("data", onData);
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
