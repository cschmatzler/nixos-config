import fs from "node:fs";

import {
  causeMessage,
  run,
  runWithInput,
  type Config,
} from "./common";

async function seedGitHubCredential(config: Config, sandboxName: string): Promise<void> {
  try {
    const token = (await run(config.ghPath, ["auth", "token"])).stdout.trim();
    if (token.length === 0) return;
    await run(config.sbxPath, ["secret", "rm", "github", "--sandbox", sandboxName, "-f"]);
    await runWithInput(
      config.sbxPath,
      ["secret", "set", "github", "--sandbox", sandboxName],
      token,
    );
  } catch (cause: unknown) {
    console.error(
      `[herdr-sandbox] could not seed the github secret for ${sandboxName}: ${causeMessage(cause)}`,
    );
  }
}

async function seedSupermemoryCredential(config: Config, sandboxName: string): Promise<void> {
  try {
    const key = fs.readFileSync(config.supermemoryApiKeyPath, "utf8").trim();
    if (key.length === 0) return;
    const placeholder = `herdr-supermemory-${sandboxName}`;
    await run(config.sbxPath, [
      "secret", "rm", "--placeholder", placeholder, "--sandbox", sandboxName, "-f",
    ]);
    await run(config.sbxPath, [
      "secret", "set-custom",
      "--sandbox", sandboxName,
      "--host", "api.supermemory.ai",
      "--env", "SUPERMEMORY_API_KEY",
      "--placeholder", placeholder,
      "--value", key,
    ]);
  } catch (cause: unknown) {
    console.error(
      `[herdr-sandbox] could not seed the supermemory secret for ${sandboxName}: ${causeMessage(cause)}`,
    );
  }
}

/**
 * Seed credentials that the Docker Sandbox proxy exposes only to one workspace guest.
 *
 * @param config - Parsed Herdr sandbox runtime configuration.
 * @param sandboxName - Docker Sandbox receiving the scoped credentials.
 */
export async function seedProxyCredentials(
  config: Config,
  sandboxName: string,
): Promise<void> {
  await Promise.all([
    seedGitHubCredential(config, sandboxName),
    seedSupermemoryCredential(config, sandboxName),
  ]);
}

/** Remove credentials created globally by versions predating sandbox scoping. */
export async function removeLegacyGlobalProxyCredentials(config: Config): Promise<void> {
  await Promise.allSettled([
    run(config.sbxPath, ["secret", "rm", "github", "-f"]),
    run(config.sbxPath, [
      "secret", "rm", "--placeholder", "herdr-supermemory", "-f",
    ]),
  ]);
}
