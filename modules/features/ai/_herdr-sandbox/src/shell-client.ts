import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { backup, DatabaseSync } from "node:sqlite";

import {
  causeMessage,
  enforceRestrictiveNetworkPolicy,
  ensureSbxDaemon,
  listSandboxes,
  mappingsDirectory,
  readConfig,
  run,
  sandboxDockerEnvironment,
  signWorkspaceToken,
  tokenSecretPath,
  waitForExit,
  withLock,
  type SandboxState,
} from "./common";
import { snapshot } from "./herdr";
import { ensureSandboxTemplate } from "./sandbox-template";
import { seedProxyCredentials } from "./proxy-credentials";

const AUTH_PATHS = [
  ".pi/agent/auth.json",
  ".pi/agent/mcp-auth.json",
  ".pi/agent/mcp-oauth",
  ".pi/agent/trust.json",
  ".local/share/devenv/cachix_trusted_keys.json",
  ".claude/.credentials.json",
];

const RUNTIME_COPY_PATHS = [
  ...AUTH_PATHS,
  ".config/gh/config.yml",
  ".claude/CLAUDE.md",
  ".claude/agents",
  ".claude/hooks",
  ".claude.json",
];

const DEPENDENCY_CACHE_MARKER = ".herdr-sandbox-dependencies-v2";
const DEVENV_CACHE_MARKER = ".herdr-sandbox-devenv-v2";
const SANDBOX_HOSTNAME = "herdr-sandbox";
const SANDBOX_WORKSPACE_ROOT = "/home/agent/workspace";

const DEPENDENCY_INPUT_NAMES = new Set([
  ".npmrc",
  ".yarnrc",
  ".yarnrc.yml",
  "aube-lock.yaml",
  "aube-workspace.yaml",
  "bun.lock",
  "bun.lockb",
  "bunfig.toml",
  "deno.json",
  "deno.jsonc",
  "deno.lock",
  "npm-shrinkwrap.json",
  "package-lock.json",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
  "yarn.lock",
]);

const DEVENV_INPUT_NAMES = new Set([
  ".env",
  "devenv.lock",
  "devenv.nix",
  "devenv.yaml",
  "flake.lock",
  "flake.nix",
]);

const config = readConfig();

function cwdWithin(root: string): string {
  const cwd = process.cwd();
  if (cwd.startsWith(root)) return cwd;
  return root;
}

function hostHomeFiles(): string | undefined {
  const gcroot = path.join(
    config.hostHome,
    ".local/state/home-manager/gcroots/current-home/home-files",
  );
  try {
    return fs.realpathSync(gcroot);
  } catch {
    return undefined;
  }
}

function openHostShell(): never {
  if (process.execve === undefined) throw new Error("Node lacks process.execve");
  process.execve(config.hostShell, [config.hostShell], process.env as Record<string, string>);
  throw new Error("execve returned");
}

async function sandboxState(name: string): Promise<SandboxState | undefined> {
  return (await listSandboxes(config)).get(name);
}

async function copyHome(name: string, paths: ReadonlyArray<string>): Promise<void> {
  const existing = paths.filter((entry) => fs.existsSync(path.join(config.hostHome, entry)));
  const tar = spawn("tar", ["-C", config.hostHome, "-cf", "-", ...existing]);
  const untar = spawn(
    config.dockerPath,
    ["exec", "-i", "-u", "agent", name, "tar", "-xf", "-", "-C", "/home/agent"],
    {
      stdio: ["pipe", "inherit", "inherit"],
      env: sandboxDockerEnvironment(config),
    },
  );
  tar.stdout.pipe(untar.stdin);
  const code = await waitForExit(untar);
  if (code !== 0) throw new Error(`copying host configuration failed (exit ${code})`);
}

type CacheFingerprints = {
  readonly dependencies: string;
  readonly devenv: string;
};

type CacheKind = "dependencies" | "devenv";

type GitWorktree = {
  readonly checkoutPath: string;
  readonly head: string | undefined;
};

type CacheCandidate = GitWorktree & {
  readonly activity: number;
};

function cacheContext(): string {
  const devenv = fs.realpathSync(path.join(config.hostHome, ".nix-profile/bin/devenv"));
  return createHash("sha256")
    .update("herdr-sandbox-cache-v2\0")
    .update(SANDBOX_HOSTNAME)
    .update("\0")
    .update(SANDBOX_WORKSPACE_ROOT)
    .update("\0/home/agent\0")
    .update(devenv)
    .digest("hex");
}

async function projectFiles(root: string): Promise<ReadonlyArray<string>> {
  const listed = await run("git", [
    "-C", root, "ls-files", "--cached", "--others", "--exclude-standard", "-z",
  ]);
  return listed.stdout.split("\0").filter((relativePath) => relativePath.length > 0).toSorted();
}

function fingerprintFiles(
  root: string,
  namespace: string,
  context: string,
  files: ReadonlyArray<string>,
): string {
  const digest = createHash("sha256").update(namespace).update("\0").update(context);
  for (const relativePath of files) {
    const absolutePath = path.join(root, relativePath);
    if (!fs.existsSync(absolutePath) || !fs.statSync(absolutePath).isFile()) continue;
    digest.update("\0").update(relativePath).update("\0").update(fs.readFileSync(absolutePath));
  }
  return digest.digest("hex");
}

async function cacheFingerprints(root: string): Promise<CacheFingerprints> {
  const files = await projectFiles(root);
  const context = cacheContext();
  const dependencyFiles = files.filter((relativePath) => {
    const name = path.basename(relativePath);
    return name === "package.json" || DEPENDENCY_INPUT_NAMES.has(name);
  });
  const devenvFiles = files.filter((relativePath) => {
    const name = path.basename(relativePath);
    return name.endsWith(".nix") || name.startsWith(".env.") || DEVENV_INPUT_NAMES.has(name);
  });
  return {
    dependencies: fingerprintFiles(root, "dependencies", context, dependencyFiles),
    devenv: fingerprintFiles(root, "devenv", context, devenvFiles),
  };
}

async function cacheFingerprintsOrUndefined(root: string): Promise<CacheFingerprints | undefined> {
  try {
    return await cacheFingerprints(root);
  } catch (cause: unknown) {
    console.error(`[herdr-sandbox] cannot fingerprint caches for ${root}: ${causeMessage(cause)}`);
    return undefined;
  }
}

function parseGitWorktree(block: string): GitWorktree | undefined {
  const lines = block.split("\n");
  const checkout = lines.find((line) => line.startsWith("worktree "));
  if (checkout === undefined) return undefined;
  const head = lines.find((line) => line.startsWith("HEAD "));
  return {
    checkoutPath: checkout.slice("worktree ".length),
    head: head?.slice("HEAD ".length),
  };
}

function cacheMarker(kind: CacheKind): string {
  if (kind === "devenv") return path.join(".devenv", DEVENV_CACHE_MARKER);
  return path.join("node_modules", DEPENDENCY_CACHE_MARKER);
}

function dependencyCacheReuse(
  root: string,
  fingerprints: CacheFingerprints | undefined,
): string | undefined {
  if (fingerprints === undefined) return undefined;
  const marker = path.join(root, cacheMarker("dependencies"));
  if (!fs.existsSync(marker)) return undefined;
  if (fs.readFileSync(marker, "utf8").trim() !== fingerprints.dependencies) return undefined;
  return "1";
}

function cacheActivityPaths(kind: CacheKind): ReadonlyArray<string> {
  if (kind === "devenv") return [cacheMarker(kind), ".devenv/nix-eval-cache.db"];
  return [cacheMarker(kind), "node_modules/.aube-state/fresh.json"];
}

function cacheActivity(checkoutPath: string, kind: CacheKind): number {
  return cacheActivityPaths(kind).reduce((latest, relativePath) => {
    try {
      return Math.max(latest, fs.statSync(path.join(checkoutPath, relativePath)).mtimeMs);
    } catch {
      return latest;
    }
  }, 0);
}

async function orderedCacheSources(
  root: string,
  kind: CacheKind,
  expectedFingerprint: string,
): Promise<ReadonlyArray<string>> {
  const currentHead = (await run("git", ["-C", root, "rev-parse", "HEAD"])).stdout.trim();
  const listed = await run("git", ["-C", root, "worktree", "list", "--porcelain"]);
  const worktrees = listed.stdout
    .trim()
    .split(/\n\n+/)
    .flatMap((block) => {
      const worktree = parseGitWorktree(block);
      return worktree === undefined ? [] : [worktree];
    })
    .filter((candidate) =>
      candidate.checkoutPath !== root && fs.existsSync(path.join(candidate.checkoutPath, ".git"))
    );
  const candidates = (
    await Promise.all(worktrees.map(async (candidate): Promise<CacheCandidate | undefined> => {
      const markerPath = path.join(candidate.checkoutPath, cacheMarker(kind));
      if (!fs.existsSync(markerPath)) return undefined;
      if (fs.readFileSync(markerPath, "utf8").trim() !== expectedFingerprint) return undefined;
      const fingerprints = await cacheFingerprintsOrUndefined(candidate.checkoutPath);
      if (fingerprints === undefined || fingerprints[kind] !== expectedFingerprint) return undefined;
      return { ...candidate, activity: cacheActivity(candidate.checkoutPath, kind) };
    }))
  ).flatMap((candidate) => (candidate === undefined ? [] : [candidate]));
  return candidates
    .toSorted((left, right) => {
      const leftMatchesHead = left.head === currentHead;
      const rightMatchesHead = right.head === currentHead;
      if (leftMatchesHead && !rightMatchesHead) return -1;
      if (!leftMatchesHead && rightMatchesHead) return 1;
      if (left.activity !== right.activity) return right.activity - left.activity;
      return left.checkoutPath.localeCompare(right.checkoutPath);
    })
    .map((candidate) => candidate.checkoutPath);
}

async function seedDevenvCache(
  root: string,
  fingerprint: string,
): Promise<void> {
  const target = path.join(root, ".devenv");
  if (fs.existsSync(target)) return;
  const sourceRoot = (await orderedCacheSources(root, "devenv", fingerprint))[0];
  if (sourceRoot === undefined) {
    process.stdout.write("[herdr-sandbox] no compatible devenv cache; setup will warm one\n");
    return;
  }
  const source = path.join(sourceRoot, ".devenv");
  try {
    await run("cp", ["-a", source, target]);
    const sourceDatabasePath = path.join(source, "nix-eval-cache.db");
    const targetDatabasePath = path.join(target, "nix-eval-cache.db");
    if (fs.existsSync(sourceDatabasePath)) {
      const snapshotPath = `${targetDatabasePath}.snapshot-${process.pid}`;
      const sourceDatabase = new DatabaseSync(sourceDatabasePath, { readOnly: true });
      try {
        await backup(sourceDatabase, snapshotPath);
      } finally {
        sourceDatabase.close();
      }
      fs.renameSync(snapshotPath, targetDatabasePath);
      fs.rmSync(`${targetDatabasePath}-shm`, { force: true });
      fs.rmSync(`${targetDatabasePath}-wal`, { force: true });
    }
    process.stdout.write(`[herdr-sandbox] reused devenv cache from ${sourceRoot}\n`);
  } catch (cause: unknown) {
    fs.rmSync(target, { recursive: true, force: true });
    console.error(`[herdr-sandbox] could not snapshot devenv cache: ${causeMessage(cause)}`);
  }
}

async function seedDependencyCache(
  root: string,
  fingerprint: string,
): Promise<void> {
  if (fs.existsSync(path.join(root, "node_modules"))) return;
  const sourceRoot = (await orderedCacheSources(root, "dependencies", fingerprint))[0];
  if (sourceRoot === undefined) {
    process.stdout.write("[herdr-sandbox] no compatible dependency cache; setup will warm one\n");
    return;
  }
  const found = await run("find", [
    sourceRoot, "-maxdepth", "3", "-name", "node_modules", "-type", "d", "-prune",
  ]);
  for (const source of found.stdout.split("\n").filter((entry) => entry.length > 0)) {
    const target = path.join(root, path.relative(sourceRoot, source));
    if (fs.existsSync(target)) continue;
    fs.mkdirSync(path.dirname(target), { recursive: true });
    await run("cp", ["-a", "--reflink=auto", source, target]);
  }
  process.stdout.write(`[herdr-sandbox] reused dependency cache from ${sourceRoot}\n`);
}

async function seedFromCompatibleCaches(root: string): Promise<void> {
  const fingerprints = await cacheFingerprintsOrUndefined(root);
  if (fingerprints === undefined) return;
  await seedDevenvCache(root, fingerprints.devenv);
  await seedDependencyCache(root, fingerprints.dependencies);
}

async function createSandbox(name: string, root: string): Promise<void> {
  const lockDir = path.join(config.stateDirectory, "locks", `${name}.lock`);
  await withLock(lockDir, async () => {
    if ((await sandboxState(name)) !== undefined) return;
    process.stdout.write("[herdr-sandbox] creating the sandbox for this worktree…\n");
    const gitDir = path.resolve(
      root,
      (await run("git", ["-C", root, "rev-parse", "--git-common-dir"])).stdout.trim(),
    );
    const template = await ensureSandboxTemplate(config);
    await seedFromCompatibleCaches(root);
    const mounts = [root];
    if (!gitDir.startsWith(`${root}${path.sep}`)) mounts.push(gitDir);
    for (const extra of [
      "/nix:ro",
      `${config.hostHome}/.pi/agent/npm:ro`,
      `${config.hostHome}/.pi/agent/git:ro`,
      `${config.hostHome}/.cache/nix:ro`,
      `${config.hostHome}/.cache/ms-playwright:ro`,
    ]) {
      if (fs.existsSync(extra.replace(/:ro$/, ""))) mounts.push(extra);
    }
    await run(config.sbxPath, [
      "create", "--quiet",
      "--name", name,
      "--cpus", String(config.guestCpus),
      "--memory", config.guestMemory,
      "--template", template,
      "--kit", config.kitPath,
      "shell", ...mounts,
    ]);
    await seedProxyCredentials(config, name);
    await copyHome(name, RUNTIME_COPY_PATHS);
  });
}

function attachEnv(
  workspaceId: string,
  root: string,
  fingerprints: CacheFingerprints | undefined,
): Array<string> {
  const values: Record<string, string | undefined> = {
    HERDR_ENV: "1",
    HERDR_WORKSPACE_ID: workspaceId,
    HERDR_TAB_ID: process.env.HERDR_TAB_ID,
    HERDR_PANE_ID: process.env.HERDR_PANE_ID,
    HERDR_SANDBOX_TOKEN: signWorkspaceToken(
      workspaceId,
      fs.readFileSync(tokenSecretPath(config), "utf8").trim(),
    ),
    HERDR_SANDBOX_BRIDGE_URL: `http://host.docker.internal:${config.listenPort}`,
    HERDR_HOST_PROFILE: fs.realpathSync(`${config.hostHome}/.nix-profile`),
    HERDR_HOST_HOME_FILES: hostHomeFiles(),
    HERDR_HOST_HOME: config.hostHome,
    HERDR_HOST_NAME: os.hostname(),
    HERDR_HOST_WORKSPACE_ROOT: root,
    HERDR_WORKSPACE_ROOT: SANDBOX_WORKSPACE_ROOT,
    HERDR_SANDBOX_HOSTNAME: SANDBOX_HOSTNAME,
    HERDR_DEVENV_CACHE_FINGERPRINT: fingerprints?.devenv,
    HERDR_DEPENDENCY_CACHE_FINGERPRINT: fingerprints?.dependencies,
    HERDR_DEPENDENCY_CACHE_REUSED: dependencyCacheReuse(root, fingerprints),
    TERM: process.env.TERM ?? "xterm-256color",
    COLORTERM: process.env.COLORTERM,
    LANG: "C.UTF-8",
  };
  return Object.entries(values).flatMap(([key, value]) => {
    if (value === undefined) return [];
    return ["-e", `${key}=${value}`];
  });
}

async function attachOnce(name: string, cwd: string, env: Array<string>): Promise<number> {
  const child = spawn(
    config.dockerPath,
    ["exec", "-it", "-u", "agent", "-w", cwd, ...env, name, "/home/agent/.local/bin/herdr-sandbox-enter"],
    {
      stdio: "inherit",
      env: sandboxDockerEnvironment(config),
    },
  );
  return await waitForExit(child);
}

async function waitForResume(name: string): Promise<void> {
  process.stdout.write("\r\n[herdr-sandbox] paused after inactivity — press enter to resume\r\n");
  await new Promise<void>((resolve) => {
    const finish = (): void => {
      clearInterval(poll);
      process.stdin.off("data", finish);
      if (process.stdin.isTTY) process.stdin.setRawMode(false);
      process.stdin.pause();
      resolve();
    };
    const poll = setInterval(() => {
      sandboxState(name).then((state) => {
        if (state === "running") finish();
      }, () => undefined);
    }, 3_000);
    if (process.stdin.isTTY) process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.once("data", finish);
  });
}

async function main(): Promise<void> {
  const workspaceId = process.env.HERDR_WORKSPACE_ID;
  if (workspaceId === undefined) openHostShell();

  const snap = await snapshot(config.herdrSocketPath);
  const worktree = snap.workspaces?.find((w: any) => w.workspace_id === workspaceId)?.worktree;
  if (worktree?.is_linked_worktree !== true) openHostShell();

  const root: string = worktree.checkout_path;
  const name = `herdr-${createHash("sha256").update(root).digest("hex").slice(0, 20)}`;
  const sandboxes = await ensureSbxDaemon(config);
  await enforceRestrictiveNetworkPolicy(config);
  let state = sandboxes.get(name);
  if (state === undefined) {
    await createSandbox(name, root);
    state = "running";
  }

  fs.mkdirSync(mappingsDirectory(config), { recursive: true, mode: 0o700 });
  fs.writeFileSync(
    path.join(mappingsDirectory(config), `${name}.json`),
    JSON.stringify({ workspacePath: root, sandboxName: name }),
  );

  const cwd = cwdWithin(root);
  const fingerprints = await cacheFingerprintsOrUndefined(root);
  while (true) {
    if (state !== "running") await run(config.sbxPath, ["exec", name, "true"]);
    await copyHome(name, AUTH_PATHS);
    const code = await attachOnce(name, cwd, attachEnv(workspaceId, root, fingerprints));
    const after = await sandboxState(name).catch(() => undefined);
    if (after === "running") process.exit(code);
    if (after === undefined) return;
    await waitForResume(name);
    state = (await sandboxState(name).catch(() => undefined)) ?? "stopped";
  }
}

main().catch((cause: unknown) => {
  console.error(`herdr-sandbox-shell: ${causeMessage(cause)}`);
  process.exit(1);
});
