import fs from "node:fs";

/** Runtime configuration for the host-side Herdr capability broker. */
export type Config = {
  readonly herdrSocketPath: string;
  readonly stateDirectory: string;
  readonly listenPort: number;
};

/** Read the Nix-generated broker configuration passed to this process. */
export function readConfig(): Config {
  const flag = process.argv.indexOf("--config");
  const configPath = process.argv[flag + 1];
  if (flag === -1 || configPath === undefined) throw new Error("usage: --config PATH");
  const parsed: unknown = JSON.parse(fs.readFileSync(configPath, "utf8"));
  if (
    typeof parsed !== "object" ||
    parsed === null ||
    !("herdrSocketPath" in parsed) ||
    !("stateDirectory" in parsed) ||
    !("listenPort" in parsed) ||
    typeof parsed.herdrSocketPath !== "string" ||
    typeof parsed.stateDirectory !== "string" ||
    typeof parsed.listenPort !== "number"
  ) {
    throw new Error("invalid Herdr sandbox broker configuration");
  }
  return {
    herdrSocketPath: parsed.herdrSocketPath,
    stateDirectory: parsed.stateDirectory,
    listenPort: parsed.listenPort,
  };
}

/** Render an unknown failure without assuming its shape. */
export function causeMessage(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

const LONG_METHODS = new Set(["agent.prompt", "agent.wait", "pane.wait_for_output"]);

/** Return the bridge timeout for a Herdr RPC method. */
export function timeoutForMethod(method: unknown): number {
  return typeof method === "string" && LONG_METHODS.has(method) ? 305_000 : 5_000;
}
