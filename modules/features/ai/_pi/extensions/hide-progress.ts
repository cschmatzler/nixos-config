import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const PLANNOTATOR_PROGRESS_WIDGET = "plannotator-progress";

function hideProgressWidget(ctx: ExtensionContext): void {
  if (ctx.mode !== "tui") return;
  ctx.ui.setWidget(PLANNOTATOR_PROGRESS_WIDGET, undefined);
}

/** Hides Plannotator's full checklist while leaving its agent-facing todo state intact. */
export default function hidePlannotatorProgress(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => hideProgressWidget(ctx));
  pi.on("tool_execution_end", (_event, ctx) => hideProgressWidget(ctx));
  pi.on("turn_end", (_event, ctx) => hideProgressWidget(ctx));
  pi.on("session_tree", (_event, ctx) => hideProgressWidget(ctx));
}
