"""Authenticate the running MCP service without putting credentials in chat."""

import ast
import getpass
import json
import sys

import requests


URL = "http://172.18.0.1:8789/mcp"


def call(method, params):
    response = requests.post(
        URL,
        headers={"Accept": "application/json, text/event-stream"},
        json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params},
        timeout=180,
    )
    response.raise_for_status()
    if response.headers.get("Content-Type", "").startswith("text/event-stream"):
        messages = [
            json.loads(line[6:])
            for line in response.text.splitlines()
            if line.startswith("data: ")
        ]
        payload = next(message for message in messages if message.get("id") == 1)
    else:
        payload = response.json()
    if "error" in payload:
        raise RuntimeError("The MCP server rejected the request.")
    return payload["result"]


def tool(name, arguments):
    result = call("tools/call", {"name": name, "arguments": arguments})
    if result.get("isError"):
        raise RuntimeError("The MCP tool failed; inspect the service logs.")
    # Upstream returns a Python dictionary literal inside a text result.
    return ast.literal_eval(result["content"][0]["text"])


def main():
    call("initialize", {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "instagram-terminal-login", "version": "1.0"},
    })
    username = input("Instagram username [reveriedotpics]: ").strip() or "reveriedotpics"
    password = getpass.getpass("Instagram password (hidden): ")
    result = tool("instagram_login_with_credentials", {
        "username": username,
        "password": password,
    })
    del password
    if result.get("status") == "needs_2fa":
        code = getpass.getpass("Authenticator code (hidden): ")
        result = tool("instagram_complete_2fa", {"code": code})
    if result.get("status") == "needs_challenge":
        print("Instagram requires a security challenge. Open Instagram and approve the login.")
        print("The upstream MCP challenge handler cannot reliably complete email/SMS challenges.")
        return 1
    if result.get("status") != "success":
        # Do not echo upstream exceptions, which may contain request details.
        print("Instagram rejected the login. No successful login was confirmed.")
        return 1
    status = tool("instagram_get_login_status", {})
    if not status.get("logged_in") or status.get("username") != username:
        print("Login returned success, but account verification failed.")
        return 1
    print(f"Connected as @{username}. The service saved the session for restarts.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (KeyboardInterrupt, EOFError):
        sys.exit("Login cancelled.")
    except Exception as error:
        sys.exit(f"Login could not complete ({type(error).__name__}).")
