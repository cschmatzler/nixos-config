#!/usr/bin/env node
"use strict";

// src/skills/login.ts
var import_node_fs3 = require("node:fs");
var import_node_path3 = require("node:path");
var import_node_os3 = require("node:os");

// src/config.ts
var import_node_fs2 = require("node:fs");
var import_node_path2 = require("node:path");
var import_node_os2 = require("node:os");

// src/services/auth.ts
var import_node_http = require("node:http");
var import_node_fs = require("node:fs");
var import_node_path = require("node:path");
var import_node_os = require("node:os");
var import_node_child_process = require("node:child_process");
var import_node_crypto = require("node:crypto");
var SUPERMEMORY_DIR = (0, import_node_path.join)((0, import_node_os.homedir)(), ".codex", "supermemory");
var CREDENTIALS_FILE = (0, import_node_path.join)(SUPERMEMORY_DIR, "credentials.json");
var AUTH_BASE_URL = process.env.SUPERMEMORY_AUTH_URL || "https://console.supermemory.ai/auth/agent-connect";
var AUTH_TIMEOUT = Number(process.env.SUPERMEMORY_AUTH_TIMEOUT) || 6e4;
var AUTH_SUCCESS_HTML = `<!DOCTYPE html>
<html><head><title>Connected - Supermemory</title><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;background:#faf9f6}
.dot{width:10px;height:10px;background:#22c55e;border-radius:50%;display:inline-block;margin-right:8px}
h1{font-size:32px;font-weight:500;color:#1a1a1a;margin:16px 0}
p{color:#666;font-size:16px}
</style></head><body>
<div><span class="dot"></span><span style="color:#22c55e;font-size:14px">Connected</span></div>
<h1>Supermemory is ready</h1>
<p>You can close this tab and return to Codex.</p>
</body></html>`;
var AUTH_ERROR_HTML = `<!DOCTYPE html>
<html><head><title>Error - Supermemory</title><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;background:#faf9f6}
.dot{width:10px;height:10px;background:#ef4444;border-radius:50%;display:inline-block;margin-right:8px}
h1{font-size:32px;font-weight:500;color:#1a1a1a;margin:16px 0}
p{color:#666;font-size:16px}
</style></head><body>
<div><span class="dot"></span><span style="color:#ef4444;font-size:14px">Error</span></div>
<h1>Connection Failed</h1>
<p>Invalid API key received. Please try again.</p>
</body></html>`;
function loadCredentials() {
  try {
    if ((0, import_node_fs.existsSync)(CREDENTIALS_FILE)) {
      const data = JSON.parse((0, import_node_fs.readFileSync)(CREDENTIALS_FILE, "utf-8"));
      if (data.apiKey) return data.apiKey;
    }
  } catch {
  }
  return void 0;
}
function saveCredentials(apiKey) {
  (0, import_node_fs.mkdirSync)(SUPERMEMORY_DIR, { recursive: true, mode: 448 });
  (0, import_node_fs.writeFileSync)(
    CREDENTIALS_FILE,
    JSON.stringify({ apiKey, savedAt: (/* @__PURE__ */ new Date()).toISOString() }, null, 2),
    { mode: 384 }
  );
}
function openBrowser(url) {
  const onError = () => {
  };
  if (process.platform === "win32") {
    (0, import_node_child_process.execFile)("explorer.exe", [url], onError);
  } else if (process.platform === "darwin") {
    (0, import_node_child_process.execFile)("open", [url], onError);
  } else {
    (0, import_node_child_process.execFile)("xdg-open", [url], onError);
  }
}
function startAuthFlow() {
  return new Promise((resolve, reject) => {
    let resolved = false;
    const stateToken = (0, import_node_crypto.randomBytes)(16).toString("hex");
    const server = (0, import_node_http.createServer)((req, res) => {
      const url = new URL(req.url || "/", "http://localhost");
      if (url.pathname === "/callback") {
        const callbackState = url.searchParams.get("state");
        if (callbackState !== stateToken) {
          res.writeHead(403, { "Content-Type": "text/html" });
          res.end(AUTH_ERROR_HTML);
          return;
        }
        const apiKey = url.searchParams.get("apikey") || url.searchParams.get("api_key");
        if (apiKey?.startsWith("sm_")) {
          saveCredentials(apiKey);
          res.writeHead(200, { "Content-Type": "text/html" });
          res.end(AUTH_SUCCESS_HTML);
          resolved = true;
          clearTimeout(timer);
          server.close();
          resolve(apiKey);
        } else {
          res.writeHead(400, { "Content-Type": "text/html" });
          res.end(AUTH_ERROR_HTML);
        }
      } else {
        res.writeHead(404);
        res.end("Not found");
      }
    });
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      const callbackUrl = `http://localhost:${port}/callback?state=${stateToken}`;
      const params = new URLSearchParams({
        callback: callbackUrl,
        client: "codex",
        hostname: `codex - ${(0, import_node_os.hostname)()}`,
        os: `${(0, import_node_os.platform)()}-${(0, import_node_os.arch)()}`,
        cwd: process.cwd(),
        cli_version: "1.0.0"
      });
      const authUrl = `${AUTH_BASE_URL}?${params.toString()}`;
      openBrowser(authUrl);
    });
    server.on("error", (err) => {
      if (!resolved) {
        clearTimeout(timer);
        reject(new Error(`Failed to start auth server: ${err.message}`));
      }
    });
    const timer = setTimeout(() => {
      if (!resolved) {
        server.close();
        reject(new Error("AUTH_TIMEOUT"));
      }
    }, AUTH_TIMEOUT);
  });
}

// src/config.ts
var CONFIG_FILE = (0, import_node_path2.join)((0, import_node_os2.homedir)(), ".codex", "supermemory.json");
var DEFAULT_SIGNAL_KEYWORDS = [
  // Preferences (single words to match "i really like", "i always prefer", etc.)
  "prefer",
  "like",
  "love",
  "use",
  "hate",
  "dislike",
  "avoid",
  // Memory commands
  "remember",
  "forget",
  "note",
  // Decisions & Architecture
  "decision",
  "decided",
  "chose",
  "choose",
  "picked",
  "switched",
  "moved",
  "migrated",
  "architecture",
  "pattern",
  "approach",
  "design",
  "tradeoff",
  // Technical
  "implementation",
  "refactor",
  "upgrade",
  "deprecate",
  // Problem solving
  "bug",
  "fix",
  "fixed",
  "solved",
  "solution",
  "important",
  // Stack/tools
  "stack",
  "framework",
  "library",
  "tool",
  "database"
];
var DEFAULTS = {
  similarityThreshold: 0.6,
  maxMemories: 5,
  maxProfileItems: 5,
  injectProfile: true,
  containerTagPrefix: "codex",
  filterPrompt: "You are a stateful coding agent. Remember all the information, including but not limited to user's coding preferences, tech stack, behaviours, workflows, and any other relevant details.",
  debug: false,
  // Signal extraction - disabled by default, captures everything
  signalExtraction: false,
  signalKeywords: DEFAULT_SIGNAL_KEYWORDS,
  signalTurnsBefore: 3,
  // Auto-save interval
  autoSaveEveryTurns: 3
};
function loadConfig() {
  if ((0, import_node_fs2.existsSync)(CONFIG_FILE)) {
    try {
      const content = (0, import_node_fs2.readFileSync)(CONFIG_FILE, "utf-8");
      return JSON.parse(content);
    } catch {
    }
  }
  return {};
}
var fileConfig = loadConfig();
function getApiKey() {
  if (process.env.SUPERMEMORY_CODEX_API_KEY) return process.env.SUPERMEMORY_CODEX_API_KEY;
  if (fileConfig.apiKey) return fileConfig.apiKey;
  return loadCredentials();
}
var SUPERMEMORY_API_KEY = getApiKey();
var CONFIG = {
  similarityThreshold: fileConfig.similarityThreshold ?? DEFAULTS.similarityThreshold,
  maxMemories: fileConfig.maxMemories ?? DEFAULTS.maxMemories,
  maxProfileItems: fileConfig.maxProfileItems ?? DEFAULTS.maxProfileItems,
  injectProfile: fileConfig.injectProfile ?? DEFAULTS.injectProfile,
  containerTagPrefix: fileConfig.containerTagPrefix ?? DEFAULTS.containerTagPrefix,
  userContainerTag: fileConfig.userContainerTag,
  projectContainerTag: fileConfig.projectContainerTag,
  filterPrompt: fileConfig.filterPrompt ?? DEFAULTS.filterPrompt,
  debug: fileConfig.debug ?? DEFAULTS.debug,
  // Signal extraction
  signalExtraction: fileConfig.signalExtraction ?? DEFAULTS.signalExtraction,
  signalKeywords: fileConfig.signalKeywords ?? DEFAULTS.signalKeywords,
  signalTurnsBefore: fileConfig.signalTurnsBefore ?? DEFAULTS.signalTurnsBefore,
  // Auto-save interval
  autoSaveEveryTurns: fileConfig.autoSaveEveryTurns ?? DEFAULTS.autoSaveEveryTurns
};
function isConfigured() {
  return !!SUPERMEMORY_API_KEY;
}

// src/skills/login.ts
var AUTH_ATTEMPTED_FILE = (0, import_node_path3.join)((0, import_node_os3.homedir)(), ".codex", "supermemory", ".auth-attempted");
async function main() {
  try {
    if ((0, import_node_fs3.existsSync)(AUTH_ATTEMPTED_FILE)) (0, import_node_fs3.unlinkSync)(AUTH_ATTEMPTED_FILE);
  } catch {
  }
  if (isConfigured()) {
    console.log("Already authenticated with Supermemory. Memory is active.");
    console.log(`To re-authenticate, remove ${CREDENTIALS_FILE} and run this again.`);
    return;
  }
  console.log("Opening browser to authenticate with Supermemory...");
  console.log(`If the browser does not open, visit: ${AUTH_BASE_URL}`);
  try {
    await startAuthFlow();
    try {
      if ((0, import_node_fs3.existsSync)(AUTH_ATTEMPTED_FILE)) (0, import_node_fs3.unlinkSync)(AUTH_ATTEMPTED_FILE);
    } catch {
    }
    console.log("\nAuthenticated successfully! Supermemory is now active.");
  } catch (err) {
    const isTimeout = err instanceof Error && err.message === "AUTH_TIMEOUT";
    if (isTimeout) {
      console.error("\nAuthentication timed out. Please try again.");
    } else {
      console.error("\nAuthentication failed:", err instanceof Error ? err.message : err);
    }
    console.error(`
Alternatively, set the API key manually:`);
    console.error(`  export SUPERMEMORY_CODEX_API_KEY="sm_..."`);
    console.error(`  Get your key at: https://console.supermemory.ai/keys`);
    process.exit(1);
  }
}
main().catch((err) => {
  console.error("Fatal:", err instanceof Error ? err.message : err);
  process.exit(1);
});
