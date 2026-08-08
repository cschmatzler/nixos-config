#!/usr/bin/env bun
import { updateWorkspacePullRequests } from "../src/main";

const herdrBin = process.env.HERDR_BIN_PATH ?? "herdr";
let workspaceId: string | undefined;
if (process.env.HERDR_PLUGIN_EVENT !== "startup") {
  workspaceId = process.env.HERDR_WORKSPACE_ID;
}

try {
  await updateWorkspacePullRequests(herdrBin, workspaceId);
} catch (cause) {
  console.error("[gh-pr-workspace] unexpected refresh failure", cause);
  process.exitCode = 1;
}
