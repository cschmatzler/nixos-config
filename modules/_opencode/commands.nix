{...}: {
	"supermemory-init" = ''
		---
		description: Initialize Supermemory with codebase knowledge
		---

		# Supermemory Init

		Initialize persistent memory for this codebase.

		1. Check existing project memories with the `supermemory` tool.
		2. Read project instructions, manifests, config, CI, and key source directories.
		3. Save concise project-scoped memories for commands, architecture, conventions, and known gotchas.
		4. Save user-scoped memories only for durable personal preferences.
		5. Summarize what was saved and note any gaps.
	'';

	"supermemory-login" = ''
		---
		description: Authenticate with Supermemory via browser
		---

		# Supermemory Login

		Run:

		```bash
		bunx opencode-supermemory@latest login
		```

		After the browser flow completes, report whether authentication succeeded.
	'';

	"supermemory-logout" = ''
		---
		description: Log out from Supermemory and clear credentials
		---

		# Supermemory Logout

		Run:

		```bash
		bunx opencode-supermemory@latest logout
		```

		Report whether logout succeeded and note that `/supermemory-login` is needed to reconnect.
	'';

	"supermemory-status" = ''
		---
		description: Show Supermemory connection status
		---

		# Supermemory Status

		Run:

		```bash
		bunx opencode-supermemory@latest status
		```

		Report the connection status, credential source, API URL, and account information if available.
	'';
}
