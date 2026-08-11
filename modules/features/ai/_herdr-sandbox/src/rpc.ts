const LONG_METHODS = new Set(["agent.prompt", "agent.wait", "pane.wait_for_output"]);

/** Return the broker timeout for a Herdr RPC method. */
export function timeoutForMethod(method: string): number {
  return LONG_METHODS.has(method) ? 305_000 : 5_000;
}
