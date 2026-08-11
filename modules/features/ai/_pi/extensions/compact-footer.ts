import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const ANSI_ESCAPE = /\x1b\[[0-?]*[ -/]*[@-~]/g;

type MemoryConnection = "checking" | "connected" | "disconnected";

function plainText(value: string | undefined): string | undefined {
  return value?.replace(ANSI_ESCAPE, "");
}

function sessionTokens(ctx: ExtensionContext): { readonly input: number; readonly output: number } {
  return ctx.sessionManager.getBranch().reduce(
    (total, entry) => {
      if (entry.type !== "message" || entry.message.role !== "assistant") return total;
      return {
        input: total.input + entry.message.usage.input,
        output: total.output + entry.message.usage.output,
      };
    },
    { input: 0, output: 0 },
  );
}

function formatTokenCount(tokens: number): string {
  if (tokens < 1_000) return `${tokens}`;
  if (tokens < 1_000_000) return `${(tokens / 1_000).toFixed(tokens < 10_000 ? 1 : 0)}k`;
  return `${(tokens / 1_000_000).toFixed(1)}M`;
}

function formatTokens(tokens: { readonly input: number; readonly output: number }): string {
  return `${formatTokenCount(tokens.input)}/${formatTokenCount(tokens.output)}`;
}

function formatContext(ctx: ExtensionContext): string | undefined {
  const percent = ctx.getContextUsage()?.percent;
  return percent === null || percent === undefined ? undefined : `ctx ${Math.round(percent)}%`;
}

function formatCache(status: string | undefined): { readonly text: string; readonly warning: boolean } | undefined {
  const plain = plainText(status);
  if (!plain) return undefined;
  if (plain.includes("disabled")) return { text: "cache off", warning: true };

  const hitRate = plain.match(/\(([0-9]+(?:\.[0-9]+)?)%\)/)?.[1];
  if (!hitRate) return undefined;

  const warning = plain.includes("compat") || plain.includes("integrity");
  return { text: `cache ${hitRate}%${warning ? " ⚠" : ""}`, warning };
}

function formatMcp(status: string | undefined): { readonly text: string; readonly connected: boolean } | undefined {
  const plain = plainText(status);
  if (!plain) return undefined;
  if (plain.toLowerCase().includes("connecting")) return { text: "MCP …", connected: false };

  const counts = plain.match(/MCP:\s*([0-9]+)\/([0-9]+)/i);
  if (counts) {
    const connected = Number(counts[1]);
    const total = Number(counts[2]);
    return {
      text: `MCP ${connected}/${total}`,
      connected: total > 0 && connected === total,
    };
  }

  const count = plain.match(/(?:^|\s)([0-9]+)\s+MCP\b/i)?.[1];
  return count ? { text: `MCP ${count}`, connected: Number(count) > 0 } : undefined;
}

function memoryConnection(status: string | undefined): MemoryConnection | undefined {
  const plain = plainText(status)?.toLowerCase();
  if (!plain) return undefined;
  if (plain.includes("not configured") || plain.includes("error")) return "disconnected";
  if (plain.includes("recalling")) return "checking";
  if (plain.includes("remote") || plain.includes("local") || plain.includes("recalled")) return "connected";
  return undefined;
}

/** Installs a one-line footer with only actionable session and connection information. */
export default function compactFooter(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((_tui, theme, footerData) => ({
      invalidate() {},
      render(width: number): string[] {
        const statuses = footerData.getExtensionStatuses();
        const model = ctx.model?.id ?? "no model";
        const parts = [
          theme.fg("muted", model),
          theme.fg("muted", pi.getThinkingLevel()),
          theme.fg("dim", formatTokens(sessionTokens(ctx))),
        ];

        const context = formatContext(ctx);
        if (context) parts.push(theme.fg("dim", context));

        const cache = formatCache(statuses.get("pi-cache-stats"));
        if (cache) parts.push(theme.fg(cache.warning ? "warning" : "dim", cache.text));

        const mcp = formatMcp(statuses.get("mcp"));
        if (mcp) parts.push(theme.fg(mcp.connected ? "success" : "warning", mcp.text));

        const memory = memoryConnection(statuses.get("supermemory"));
        if (memory === "checking") parts.push(theme.fg("dim", "memory ?"));
        if (memory === "connected") parts.push(theme.fg("success", "memory ✓"));
        if (memory === "disconnected") parts.push(theme.fg("warning", "memory ✗"));

        return [truncateToWidth(parts.join(theme.fg("dim", " · ")), width, "")];
      },
    }));
  });
}
