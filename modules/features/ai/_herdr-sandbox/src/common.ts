import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createHmac, timingSafeEqual } from "node:crypto";
import { execFile, spawn, type ChildProcess } from "node:child_process";
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
  readonly ghPath: string;
  readonly supermemoryApiKeyPath: string;
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

export function causeMessage(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

export function sandboxDockerEnvironment(config: Config): NodeJS.ProcessEnv {
  return { ...process.env, DOCKER_HOST: `unix://${config.dockerSocketPath}` };
}

export function waitForExit(child: ChildProcess): Promise<number> {
  return new Promise((resolve) => child.on("close", (code) => resolve(code ?? 1)));
}

export function runWithInput(
  command: string,
  args: ReadonlyArray<string>,
  input: string,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, [...args], { stdio: ["pipe", "ignore", "inherit"] });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} exited ${code ?? "with a signal"}`));
    });
    child.stdin?.end(input);
  });
}

const LONG_METHODS = new Set(["agent.prompt", "agent.wait", "pane.wait_for_output"]);

export function timeoutForMethod(method: unknown): number {
  return typeof method === "string" && LONG_METHODS.has(method) ? 305_000 : 5_000;
}

function processIsAlive(pidPath: string): boolean {
  try {
    process.kill(Number(fs.readFileSync(pidPath, "utf8")), 0);
    return true;
  } catch {
    return false;
  }
}

export async function withLock(lockDir: string, action: () => Promise<void>): Promise<void> {
  fs.mkdirSync(path.dirname(lockDir), { recursive: true });
  for (let attempt = 0; ; attempt += 1) {
    try {
      fs.mkdirSync(lockDir);
      fs.writeFileSync(path.join(lockDir, "pid"), String(process.pid));
      break;
    } catch {
      if (attempt >= 360) throw new Error(`timed out waiting for ${lockDir}`);
      if (processIsAlive(path.join(lockDir, "pid"))) {
        await new Promise((resolve) => setTimeout(resolve, 1_000));
      } else {
        fs.rmSync(lockDir, { recursive: true, force: true });
      }
    }
  }
  try {
    await action();
  } finally {
    fs.rmSync(lockDir, { recursive: true, force: true });
  }
}

export async function ensureSbxDaemon(config: Config): Promise<Map<string, SandboxState>> {
  try {
    return await listSandboxes(config);
  } catch {
    await run(config.sbxPath, ["daemon", "start", "--detach", "--policy", "deny-all"]);
  }
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      return await listSandboxes(config);
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }
  throw new Error("Docker Sandboxes daemon did not come up; try `sbx daemon start`");
}

const BALANCED_NETWORK_RULE_IDS = [
  "default-ai-services",
  "default-package-managers",
  "default-code-and-containers",
  "default-cloud-infrastructure",
  "default-os-packages",
  "default-cert-validation",
] as const;

/**
 * Remove Docker Sandbox's broad default network grants.
 *
 * Herdr workspace guests receive their required destinations from their kit policy.
 * Existing installations retain their initial policy, so removing the known balanced
 * rules is required in addition to selecting `deny-all` for new daemon initialization.
 *
 * @param config - Parsed Herdr sandbox runtime configuration.
 */
export async function enforceRestrictiveNetworkPolicy(config: Config): Promise<void> {
  const marker = path.join(config.stateDirectory, "network-policy-v1");
  if (fs.existsSync(marker)) return;
  const lockDir = path.join(config.stateDirectory, "locks", "network-policy.lock");
  await withLock(lockDir, async () => {
    if (fs.existsSync(marker)) return;
    const listed = await run(config.sbxPath, [
      "policy", "ls", "--source", "local", "--type", "network", "--json",
    ]);
    const response: unknown = JSON.parse(listed.stdout);
    if (typeof response !== "object" || response === null || !("rules" in response)) {
      throw new Error("Docker Sandbox returned an invalid network policy response");
    }
    const rules = (response as { readonly rules?: unknown }).rules;
    if (!Array.isArray(rules)) {
      throw new Error("Docker Sandbox returned an invalid network policy rule list");
    }
    const activeIds = new Set(
      rules.flatMap((rule) => {
        if (typeof rule !== "object" || rule === null || !("id" in rule)) return [];
        const id = (rule as { readonly id?: unknown }).id;
        return typeof id === "string" ? [id] : [];
      }),
    );
    for (const id of BALANCED_NETWORK_RULE_IDS) {
      if (activeIds.has(id)) await run(config.sbxPath, ["policy", "rm", "network", "--id", id]);
    }
    fs.writeFileSync(marker, "deny-all with kit-scoped grants\n", { mode: 0o600 });
  });
}

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
