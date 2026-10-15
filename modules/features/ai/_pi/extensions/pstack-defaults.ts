import { readFileSync } from "node:fs";
import { dirname } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Attach pstack's full skill to a new conversation without starting another turn. */
export default function pstackDefaults(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (event, ctx) => {
    if (event.messageType !== "user") return;

    const alreadyStarted = ctx.sessionManager.getBranch().some(
      (entry) =>
        entry.type === "compaction" ||
        (entry.type === "message" && ["user", "assistant"].includes(entry.message.role)) ||
        (entry.type === "custom" && entry.customType === "pstack-mode"),
    );
    // A pstack entry also preserves an explicit /poteto-mode off before the first prompt.
    if (alreadyStarted) return;

    const skill = pi.getCommands().find(
      (command) => command.source === "skill" && command.name === "skill:poteto-mode",
    );
    const path = skill?.sourceInfo.path;
    if (!path) {
      ctx.ui.notify("Default poteto-mode skill is unavailable; check the pi-pstack package.", "warning");
      return;
    }

    const body = readFileSync(path, "utf8").replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n|$)/, "").trim();
    pi.appendEntry("pstack-mode", { enabled: true });
    ctx.ui.setStatus("pstack-mode", "pstack: poteto mode");

    return {
      message: {
        customType: "default-poteto-mode",
        content: `<skill name="poteto-mode" location="${path}">\nReferences are relative to ${dirname(path)}.\n\n${body}\n</skill>`,
        display: false,
      },
    };
  });
}
