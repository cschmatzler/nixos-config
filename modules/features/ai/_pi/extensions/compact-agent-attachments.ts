import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Match Herdsman's serialized attachment prefix, including reference-only files.
const ATTACHMENT = /^<file name="[^"\n]+"(?: path="[^"\n]+")? bytes="\d+"(?: \/>|>\n[\s\S]*?\n<\/file>)\n\n/;

/** Keep attachment payloads in context, but out of managed Agents' task display. */
export default function compactAgentAttachments(pi: ExtensionAPI): void {
  if (!process.env.PI_HERDSMAN_MAILBOX) return;

  pi.registerMarkdownTransformer((markdown, { messageType }) => {
    if (messageType !== "user") return markdown;

    let task = markdown;
    let count = 0;
    let attachment: RegExpMatchArray | null;
    while ((attachment = task.match(ATTACHMENT))) {
      task = task.slice(attachment[0].length);
      count += 1;
    }

    // Leave ordinary messages and unrecognized payload formats untouched.
    if (count === 0 || !task.startsWith("Task:\n")) return markdown;

    return `${task}\n\n_${count} file${count === 1 ? "" : "s"} attached_`;
  });
}
