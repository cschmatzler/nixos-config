from instagram_mcp_server.mcp_server import mcp


# Tailscale Serve provides private HTTPS access to this loopback listener.
mcp.run(transport="http", host="127.0.0.1", port=8789, stateless_http=True)
