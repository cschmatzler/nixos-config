#!/usr/bin/env bun
import {updateWorkspacePullRequests} from "../src/main";

const REFRESH_INTERVAL_MS = 30_000;
const herdrBin = process.env.HERDR_BIN_PATH ?? "herdr";
const herdrProcessId = process.ppid;

function isHerdrRunning(): boolean {
  try {
    process.kill(herdrProcessId, 0);
    return true;
  } catch {
    return false;
  }
}

while (isHerdrRunning()) {
  const refreshStartedAt = Date.now();
  try {
    await updateWorkspacePullRequests(herdrBin);
  } catch (cause) {
    console.error("[gh-pr-workspace] unexpected polling failure", cause);
  }

  const refreshDuration = Date.now() - refreshStartedAt;
  const waitDuration = Math.max(0, REFRESH_INTERVAL_MS - refreshDuration);
  await Bun.sleep(waitDuration);
}
