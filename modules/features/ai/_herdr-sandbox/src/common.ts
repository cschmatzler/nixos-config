import fs from "node:fs";
import http from "node:http";
import { createHmac, timingSafeEqual } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

export type Config = {
  readonly herdrSocketPath: string;
  readonly stateDirectory: string;
  readonly listenPort: number;
  readonly sbxPath: string;
  readonly dockerPath: string;
  readonly dockerSocketPath: string;
  readonly kitPath: string;
  readonly hostShell: string;
  readonly hostHome: string;
  readonly guestCpus: number;
  readonly guestMemory: string;
  readonly idleMinutes: number;
};

export function readConfig(): Config {
  const flag = process.argv.indexOf("--config");
  const path = process.argv[flag + 1];
  if (flag === -1 || path === undefined) throw new Error("usage: --config PATH");
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

export function tokenSecretPath(config: Config): string {
  return `${config.stateDirectory}/capability.key`;
}

export function mappingsDirectory(config: Config): string {
  return `${config.stateDirectory}/workspaces`;
}

export function signWorkspaceToken(workspaceId: string, secret: string): string {
  const payload = Buffer.from(workspaceId, "utf8").toString("base64url");
  const digest = createHmac("sha256", secret).update(payload).digest("base64url");
  return `${payload}.${digest}`;
}

export function verifyWorkspaceToken(token: string, secret: string): string | undefined {
  const [payload, digest] = token.split(".");
  if (payload === undefined || digest === undefined) return undefined;
  const expected = createHmac("sha256", secret).update(payload).digest();
  const provided = Buffer.from(digest, "base64url");
  if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
    return undefined;
  }
  return Buffer.from(payload, "base64url").toString("utf8");
}

export const run = promisify(execFile);

export async function dockerRequest(config: Config, path: string): Promise<any> {
  return await new Promise((resolve, reject) => {
    const request = http.request(
      { socketPath: config.dockerSocketPath, path, method: "GET" },
      (response) => {
        let body = "";
        response.on("data", (chunk) => (body += chunk));
        response.on("end", () => {
          if ((response.statusCode ?? 500) >= 400) {
            reject(new Error(`docker ${path}: ${response.statusCode} ${body.slice(0, 200)}`));
          } else {
            resolve(JSON.parse(body));
          }
        });
      },
    );
    request.on("error", reject);
    request.end();
  });
}

export type SandboxState = "running" | "stopped";

export async function listSandboxes(config: Config): Promise<Map<string, SandboxState>> {
  const containers = await dockerRequest(config, "/containers/json?all=true");
  const states = new Map<string, SandboxState>();
  for (const container of containers) {
    const name = container.Names?.[0]?.replace(/^\//, "");
    if (typeof name === "string" && name.startsWith("herdr-")) {
      states.set(name, container.State === "running" ? "running" : "stopped");
    }
  }
  return states;
}
