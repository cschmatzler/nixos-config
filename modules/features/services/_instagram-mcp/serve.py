import os

from instagram_mcp_server.mcp_server import mcp


mcp.run(
    transport="http",
    host=os.environ.get("INSTAGRAM_MCP_HOST", "127.0.0.1"),
    port=8789,
    stateless_http=True,
)
