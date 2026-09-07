# Instagram MCP on Tahani

The `instagram-mcp` systemd service listens on Tahani's Docker bridge at
`172.18.0.1:8789`. Executor maps `host.docker.internal` to Docker's host gateway,
so add **`http://host.docker.internal:8789/mcp`** as a remote MCP server in Executor
after deploying. Executor already enables `EXECUTOR_ALLOW_LOCAL_NETWORK`.

Tahani pins Docker's bridge address and starts the MCP service after Docker.
Its firewall already trusts `docker0`. No Tailscale Serve endpoint is needed.
The MCP server has no separate authentication and shares one Instagram account
among callers that can reach the bridge listener, including other local containers.

Browser cookies can be rejected by Instagram's mobile API even when they work
on the website. On Tahani, use `login.py` with the running service's Python
environment to enter a password and, if requested, an authenticator code:

```bash
instagram_python=$(systemctl show instagram-mcp.service -p ExecStart --value | sed -n 's/.*path=\([^ ;]*\).*/\1/p')
"$instagram_python" modules/features/services/_instagram-mcp/login.py
```

This logs into the running service and checks the resulting account. Passwords
are entered with terminal echo disabled and are not written to the repository.
The upstream email/SMS challenge handler is not reliable; the helper reports
that case rather than treating its code as an authenticator code.

Upstream stores session data in `$HOME/.instagram_mcp_session.json`. The service
sets `$HOME` to its persistent `/var/lib/instagram-mcp` state directory, with
directory mode `0700` and a `0077` umask. Treat that file as a secret; upstream
writes JSON, not encrypted storage. Restarts restore the saved session.

Inspect service logs with `journalctl -u instagram-mcp`.
