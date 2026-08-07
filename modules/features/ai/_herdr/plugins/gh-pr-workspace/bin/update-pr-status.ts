#!/usr/bin/env bun
import {updateWorkspacePullRequests} from "../src/main";

updateWorkspacePullRequests().catch((cause: unknown) => {
  console.error("[gh-pr-workspace] unexpected refresh failure", cause);
});
