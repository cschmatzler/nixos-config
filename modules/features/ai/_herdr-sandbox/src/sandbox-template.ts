import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";

import {
  causeMessage,
  run,
  sandboxDockerEnvironment,
  waitForExit,
  withLock,
  type Config,
} from "./common";

function hostDockerEnvironment(): NodeJS.ProcessEnv {
  return Object.fromEntries(
    Object.entries(process.env).filter(([name]) => name !== "DOCKER_HOST"),
  );
}

function templateDirectory(config: Config): string {
  return path.resolve(config.kitPath, "../template");
}

function templateImage(config: Config): string {
  const directory = templateDirectory(config);
  const dockerfile = fs.readFileSync(path.join(directory, "Dockerfile"));
  const rootHelper = fs.readFileSync(path.join(directory, "herdr-sandbox-root"));
  const identity = createHash("sha256")
    .update("herdr-sandbox-template-v2\0")
    .update(dockerfile)
    .update("\0")
    .update(rootHelper)
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
  const [saveCode, loadCode] = await Promise.all([waitForExit(save), waitForExit(load)]);
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

  const lockDir = path.join(config.stateDirectory, "locks", `${image.replace(":", "-")}.lock`);
  await withLock(lockDir, async () => {
    if (await imageExists(config, image, sandboxEnvironment)) return;
    try {
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
    } catch (cause: unknown) {
      throw new Error(`failed to prepare ${image}: ${causeMessage(cause)}`, { cause });
    }
  });
  return image;
}
