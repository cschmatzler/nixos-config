#!/usr/bin/env bun
import { refreshWorkspacePrStatus } from "../src/workspace-pr-status";

const herdrBin = process.env.HERDR_BIN_PATH ?? "herdr";
let workspaceId: string | undefined;
if (process.env.HERDR_PLUGIN_EVENT !== "startup") {
  workspaceId = process.env.HERDR_WORKSPACE_ID;
}

try {
  await refreshWorkspacePrStatus(herdrBin, workspaceId);
} catch (cause) {
  console.error("[gh-pr-workspace] unexpected refresh failure", cause);
  process.exitCode = 1;
}
