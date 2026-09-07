# Instagram MCP on Tahani

The `instagram-mcp` systemd service listens on `127.0.0.1:8789`. The companion
Tailscale Serve unit exposes it as `https://instagram.manticore-hippocampus.ts.net/mcp`.
The tailnet must allow Tahani to advertise `svc:instagram`, as with its other
Tailscale Services. Access is controlled by the tailnet; the MCP server has no
separate authentication and shares one Instagram account among its callers.

After deploying, add that URL as a remote MCP server in Executor or another
client. Use `instagram_login_with_sessionid` to authenticate, then
`instagram_get_login_status` to check the session. Credentials are supplied at
runtime, never through Nix configuration.

Upstream stores session data in `$HOME/.instagram_mcp_session.json`. The service
sets `$HOME` to its persistent `/var/lib/instagram-mcp` state directory, with
directory mode `0700` and a `0077` umask. Treat that file as a secret; upstream
writes JSON, not encrypted storage. Restarts restore the saved session.

Inspect service logs with `journalctl -u instagram-mcp` and the proxy with
`journalctl -u instagram-mcp-tailscale`.
