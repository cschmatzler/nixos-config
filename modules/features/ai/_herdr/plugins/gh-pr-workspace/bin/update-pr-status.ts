#!/usr/bin/env bun
import {updateWorkspacePullRequests} from "../src/main";

const herdrBin = process.env.HERDR_BIN_PATH ?? "herdr";

updateWorkspacePullRequests(herdrBin).catch((cause: unknown) => {
  console.error("[gh-pr-workspace] unexpected refresh failure", cause);
});
