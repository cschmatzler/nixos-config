/**
 * No Scripting Extension
 *
 * Blocks python, perl, ruby, php, lua, node -e, and inline bash/sh scripts.
 * Tells the LLM to use `nu -c` instead.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

const SCRIPTING_PATTERN =
	/(?:^|[;&|]\s*|&&\s*|\|\|\s*|\$\(\s*|`\s*)(?:python[23]?|perl|ruby|php|lua|node\s+-e|bash\s+-c|sh\s+-c)\s/;

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, _ctx) => {
		if (!isToolCallEventType("bash", event)) return;

		const command = event.input.command.trim();

		if (SCRIPTING_PATTERN.test(command)) {
			return {
				block: true,
				reason:
					"Do not use python, perl, ruby, php, lua, node -e, or inline bash/sh for scripting. Use `nu -c` instead.",
			};
		}
	});
}
