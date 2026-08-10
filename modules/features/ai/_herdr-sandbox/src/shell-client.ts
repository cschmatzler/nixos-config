import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";

import {
  listSandboxes,
  mappingsDirectory,
  readConfig,
  run,
  signWorkspaceToken,
  tokenSecretPath,
  type SandboxState,
} from "./common";
import { snapshot } from "./herdr";

const AUTH_PATHS = [
  ".pi/agent/auth.json",
  ".pi/agent/mcp-auth.json",
  ".pi/agent/mcp-oauth",
  ".claude/.credentials.json",
];

const HOME_COPY_PATHS = [
  ...AUTH_PATHS,
  ".config/fish",
  ".config/nvim",
  ".config/git",
  ".config/gh",
  ".pi/agent/extensions",
  ".pi/agent/prompts",
  ".pi/agent/skills",
  ".pi/agent/settings.json",
  ".pi/agent/mcp.json",
  ".plannotator/config.json",
  ".claude/settings.json",
  ".claude/CLAUDE.md",
  ".claude/commands",
  ".claude/agents",
  ".claude/skills",
  ".claude/hooks",
  ".claude.json",
];

const config = readConfig();

function openHostShell(): never {
  if (process.execve === undefined) throw new Error("Node lacks process.execve");
  process.execve(config.hostShell, [config.hostShell], process.env as Record<string, string>);
  throw new Error("execve returned");
}

async function sandboxState(name: string): Promise<SandboxState | undefined> {
  return (await listSandboxes(config)).get(name);
}

async function ensureSbxDaemon(): Promise<Map<string, SandboxState>> {
  try {
    return await listSandboxes(config);
  } catch {
    await run(config.sbxPath, ["daemon", "start", "--detach", "--policy", "balanced"]);
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

async function copyHome(name: string, paths: ReadonlyArray<string>): Promise<void> {
  const existing = paths.filter((entry) => fs.existsSync(path.join(config.hostHome, entry)));
  const tar = spawn("tar", ["-C", config.hostHome, "-cf", "-", ...existing]);
  const untar = spawn(
    config.dockerPath,
    ["exec", "-i", "-u", "agent", name, "tar", "-xf", "-", "-C", "/home/agent"],
    {
      stdio: ["pipe", "inherit", "inherit"],
      env: { ...process.env, DOCKER_HOST: `unix://${config.dockerSocketPath}` },
    },
  );
  tar.stdout.pipe(untar.stdin);
  const code = await new Promise<number>((resolve) => untar.on("close", (c) => resolve(c ?? 1)));
  if (code !== 0) throw new Error(`copying host configuration failed (exit ${code})`);
}

async function withLock(name: string, action: () => Promise<void>): Promise<void> {
  const lockDir = path.join(config.stateDirectory, "locks", `${name}.lock`);
  fs.mkdirSync(path.dirname(lockDir), { recursive: true });
  for (let attempt = 0; ; attempt += 1) {
    try {
      fs.mkdirSync(lockDir);
      fs.writeFileSync(path.join(lockDir, "pid"), String(process.pid));
      break;
    } catch {
      if (attempt >= 360) throw new Error(`timed out waiting for ${lockDir}`);
      let ownerAlive = false;
      try {
        process.kill(Number(fs.readFileSync(path.join(lockDir, "pid"), "utf8")), 0);
        ownerAlive = true;
      } catch {}
      if (ownerAlive) await new Promise((resolve) => setTimeout(resolve, 1_000));
      else fs.rmSync(lockDir, { recursive: true, force: true });
    }
  }
  try {
    await action();
  } finally {
    fs.rmSync(lockDir, { recursive: true, force: true });
  }
}

async function createSandbox(name: string, root: string): Promise<void> {
  await withLock(name, async () => {
    if ((await sandboxState(name)) !== undefined) return;
    process.stdout.write("[herdr-sandbox] creating the sandbox for this worktree…\n");
    const gitDir = path.resolve(
      root,
      (await run("git", ["-C", root, "rev-parse", "--git-common-dir"])).stdout.trim(),
    );
    const mounts = [root];
    if (!gitDir.startsWith(`${root}${path.sep}`)) mounts.push(gitDir);
    for (const extra of [
      "/nix:ro",
      "/run/secrets:ro",
      `${config.hostHome}/.pi/agent/npm:ro`,
      `${config.hostHome}/.pi/agent/git:ro`,
      `${config.hostHome}/.pi/agent/sessions`,
      `${config.hostHome}/.cache/ms-playwright:ro`,
    ]) {
      if (fs.existsSync(extra.replace(/:ro$/, ""))) mounts.push(extra);
    }
    await run(config.sbxPath, [
      "create", "--quiet",
      "--name", name,
      "--cpus", String(config.guestCpus),
      "--memory", config.guestMemory,
      "--kit", config.kitPath,
      "shell", ...mounts,
    ]);
    await copyHome(name, HOME_COPY_PATHS);
  });
}

function attachEnv(workspaceId: string, root: string): Array<string> {
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
    HERDR_HOST_HOME: config.hostHome,
    HERDR_HOST_NAME: os.hostname(),
    HERDR_WORKSPACE_ROOT: root,
    TERM: process.env.TERM ?? "xterm-256color",
    COLORTERM: process.env.COLORTERM,
  };
  return Object.entries(values).flatMap(([key, value]) =>
    value === undefined ? [] : ["-e", `${key}=${value}`],
  );
}

async function attachOnce(name: string, cwd: string, env: Array<string>): Promise<number> {
  const child = spawn(
    config.dockerPath,
    ["exec", "-it", "-u", "agent", "-w", cwd, ...env, name, "/home/agent/.local/bin/herdr-sandbox-enter"],
    {
      stdio: "inherit",
      env: { ...process.env, DOCKER_HOST: `unix://${config.dockerSocketPath}` },
    },
  );
  return await new Promise<number>((resolve) => child.on("close", (code) => resolve(code ?? 1)));
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
  let state = (await ensureSbxDaemon()).get(name);
  if (state === undefined) {
    await createSandbox(name, root);
    state = "running";
  }

  fs.mkdirSync(mappingsDirectory(config), { recursive: true, mode: 0o700 });
  fs.writeFileSync(
    path.join(mappingsDirectory(config), `${name}.json`),
    JSON.stringify({ workspacePath: root, sandboxName: name }),
  );

  const cwd = process.cwd().startsWith(root) ? process.cwd() : root;
  while (true) {
    if (state !== "running") await run(config.sbxPath, ["exec", name, "true"]);
    await copyHome(name, AUTH_PATHS);
    const code = await attachOnce(name, cwd, attachEnv(workspaceId, root));
    const after = await sandboxState(name).catch(() => undefined);
    if (after === "running") process.exit(code);
    if (after === undefined) return;
    await waitForResume(name);
    state = (await sandboxState(name).catch(() => undefined)) ?? "stopped";
  }
}

main().catch((cause: unknown) => {
  console.error(`herdr-sandbox-shell: ${cause instanceof Error ? cause.message : String(cause)}`);
  process.exit(1);
});
