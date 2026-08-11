import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";

import { run, type Config } from "./common";

function causeMessage(cause: unknown): string {
  if (cause instanceof Error) return cause.message;
  return String(cause);
}

function hostDockerEnvironment(): NodeJS.ProcessEnv {
  return Object.fromEntries(
    Object.entries(process.env).filter(([name]) => name !== "DOCKER_HOST"),
  );
}

function sandboxDockerEnvironment(config: Config): NodeJS.ProcessEnv {
  return {
    ...process.env,
    DOCKER_HOST: `unix://${config.dockerSocketPath}`,
  };
}

function templateDirectory(config: Config): string {
  return path.resolve(config.kitPath, "../template");
}

function templateImage(config: Config): string {
  const dockerfile = fs.readFileSync(path.join(templateDirectory(config), "Dockerfile"));
  const identity = createHash("sha256")
    .update("herdr-sandbox-template-v1\0")
    .update(dockerfile)
    .update("\0")
    .update(fs.realpathSync(config.sbxPath))
    .digest("hex")
    .slice(0, 20);
  return `herdr-sandbox:${identity}`;
}

async function imageExists(
  config: Config,
  image: string,
  environment: NodeJS.ProcessEnv,
): Promise<boolean> {
  try {
    await run(config.dockerPath, ["image", "inspect", image], { env: environment });
    return true;
  } catch {
    return false;
  }
}

function processIsAlive(pidPath: string): boolean {
  try {
    process.kill(Number(fs.readFileSync(pidPath, "utf8")), 0);
    return true;
  } catch {
    return false;
  }
}

async function acquireTemplateLock(
  lockDirectory: string,
  attempt = 0,
): Promise<() => void> {
  try {
    fs.mkdirSync(lockDirectory, { recursive: false });
    fs.writeFileSync(path.join(lockDirectory, "pid"), String(process.pid));
    return () => fs.rmSync(lockDirectory, { recursive: true, force: true });
  } catch (cause: unknown) {
    if (attempt >= 360) {
      throw new Error(`timed out waiting for ${lockDirectory}`, { cause });
    }
    const pidPath = path.join(lockDirectory, "pid");
    if (!processIsAlive(pidPath)) {
      fs.rmSync(lockDirectory, { recursive: true, force: true });
      return await acquireTemplateLock(lockDirectory, attempt + 1);
    }
    await new Promise((resolve) => setTimeout(resolve, 1_000));
    return await acquireTemplateLock(lockDirectory, attempt + 1);
  }
}

async function transferImage(config: Config, image: string): Promise<void> {
  const save = spawn(config.dockerPath, ["image", "save", image], {
    env: hostDockerEnvironment(),
    stdio: ["ignore", "pipe", "inherit"],
  });
  const load = spawn(config.dockerPath, ["image", "load"], {
    env: sandboxDockerEnvironment(config),
    stdio: ["pipe", "ignore", "inherit"],
  });
  if (save.stdout === null || load.stdin === null) {
    save.kill();
    load.kill();
    throw new Error("Docker image transfer did not expose a pipe");
  }
  save.stdout.pipe(load.stdin);
  const [saveCode, loadCode] = await Promise.all([
    new Promise<number>((resolve) => save.on("close", (code) => resolve(code ?? 1))),
    new Promise<number>((resolve) => load.on("close", (code) => resolve(code ?? 1))),
  ]);
  if (saveCode !== 0 || loadCode !== 0) {
    throw new Error(`Docker image transfer failed (save ${saveCode}, load ${loadCode})`);
  }
}

/**
 * Ensure the prebuilt sandbox template is available to the Docker Sandboxes daemon.
 *
 * The expensive apt layer is built once by the host Docker daemon and transferred to
 * sandboxd. Subsequent workspace creation only applies the lightweight sandbox kit.
 *
 * @param config - Parsed Herdr sandbox runtime configuration.
 * @returns The local image tag accepted by `sbx create --template`.
 */
export async function ensureSandboxTemplate(config: Config): Promise<string> {
  const image = templateImage(config);
  const sandboxEnvironment = sandboxDockerEnvironment(config);
  if (await imageExists(config, image, sandboxEnvironment)) return image;

  const locks = path.join(config.stateDirectory, "locks");
  fs.mkdirSync(locks, { recursive: true });
  const release = await acquireTemplateLock(path.join(locks, `${image.replace(":", "-")}.lock`));
  try {
    if (await imageExists(config, image, sandboxEnvironment)) return image;
    const hostEnvironment = hostDockerEnvironment();
    if (!(await imageExists(config, image, hostEnvironment))) {
      console.log(`[herdr-sandbox] building template image ${image}…`);
      await run(
        config.dockerPath,
        ["build", "--load", "--quiet", "--tag", image, templateDirectory(config)],
        { env: hostEnvironment },
      );
    }
    console.log(`[herdr-sandbox] loading template image ${image} into sandboxd…`);
    await transferImage(config, image);
    return image;
  } catch (cause: unknown) {
    throw new Error(`failed to prepare ${image}: ${causeMessage(cause)}`, { cause });
  } finally {
    release();
  }
}
