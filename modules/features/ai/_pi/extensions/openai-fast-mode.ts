import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATE_KEY = "openai-fast-mode";

function supportsFastMode(ctx: ExtensionContext): boolean {
  const model = ctx.model;
  return (
    !!model &&
    (model.provider === "openai" || model.provider === "openai-codex") &&
    ["openai-responses", "openai-codex-responses", "openai-completions"].includes(model.api)
  );
}

/** /fast opts OpenAI requests into the priority tier without changing reasoning effort. */
export default function openaiFastMode(pi: ExtensionAPI): void {
  let enabled = false;

  function updateStatus(ctx: ExtensionContext): void {
    ctx.ui.setStatus(STATE_KEY, enabled && supportsFastMode(ctx) ? "fast" : undefined);
  }

  function restoreState(ctx: ExtensionContext): void {
    enabled = false;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== STATE_KEY) continue;
      const data = entry.data as { enabled?: unknown } | undefined;
      if (typeof data?.enabled === "boolean") enabled = data.enabled;
    }
    updateStatus(ctx);
  }

  pi.on("session_start", (_event, ctx) => restoreState(ctx));
  pi.on("session_tree", (_event, ctx) => restoreState(ctx));
  pi.on("model_select", (_event, ctx) => updateStatus(ctx));

  pi.on("before_provider_request", (event, ctx) => {
    if (!enabled || !supportsFastMode(ctx)) return;
    if (typeof event.payload !== "object" || event.payload === null || Array.isArray(event.payload)) return;

    return { ...event.payload, service_tier: "priority" };
  });

  pi.registerCommand("fast", {
    description: "Toggle OpenAI priority processing (higher cost/usage): /fast [on|off|status]",
    getArgumentCompletions: (prefix) => {
      const items = ["on", "off", "status"]
        .filter((value) => value.startsWith(prefix))
        .map((value) => ({ value, label: value }));
      return items.length ? items : null;
    },
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();
      if (!["", "on", "off", "status"].includes(action)) {
        ctx.ui.notify("Usage: /fast [on|off|status]", "warning");
        return;
      }

      if (action !== "status") {
        const nextEnabled = action === "" ? !enabled : action === "on";
        if (nextEnabled && !supportsFastMode(ctx)) {
          ctx.ui.notify("Select an OpenAI model before enabling fast mode.", "warning");
          return;
        }
        if (nextEnabled !== enabled) {
          pi.appendEntry(STATE_KEY, { enabled: nextEnabled });
          enabled = nextEnabled;
        }
      }

      updateStatus(ctx);
      const status = enabled ? "on (priority tier; higher cost/usage)" : "off";
      const inactive = enabled && !supportsFastMode(ctx) ? " — inactive for this model" : "";
      ctx.ui.notify(`OpenAI fast mode ${status}${inactive}.`, "info");
    },
  });
}
