#!@python@ -I
"""Small policy boundary; agent-browser owns browser and daemon lifecycle."""
import base64
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit
import uuid

AGENT = "@agent@"
CHROMIUM = "@chromium@"
CONFIG = "@config@"
PATH = "@path@"
CA = "@ca@"
NAMESPACE = "pi-browser-v1"
ACTION_MS = 20000
CLI_SECONDS = 30
GRAMMAR = {
    "open": "URL (http://, https://, or about:blank)",
    "snapshot": "[-i] [-c]",
    "click": "REF",
    "fill": "REF TEXT",
    "press": "KEY",
    "scroll": "DIRECTION [PIXELS]",
    "wait": "REF_OR_MILLISECONDS (0..20000)",
    "eval": "JAVASCRIPT",
    "screenshot": "[--full]",
    "status": "",
    "close": "",
}


class Failure(Exception):
    def __init__(self, code, message):
        self.code, self.message = code, message
        super().__init__(message)


def require(condition, code, message):
    if not condition:
        raise Failure(code, message)


def parse(argv):
    require(len(argv) >= 2, "usage", "Expected SESSION and operation; use --help.")
    session, verb, *args = argv
    try:
        key = uuid.UUID(session)
    except ValueError:
        raise Failure("invalid_session", "SESSION must be a canonical lowercase UUID v4.")
    require(str(key) == session and key.version == 4, "invalid_session",
            "SESSION must be a canonical lowercase UUID v4.")
    require(verb in GRAMMAR, "usage", "Unknown operation; use --help.")
    require(all("\0" not in arg for arg in args), "usage", "NUL is not valid input.")
    ref = lambda value: re.fullmatch(r"@e[1-9][0-9]*", value) is not None
    number = lambda value: re.fullmatch(r"[0-9]{1,5}", value) is not None
    valid = False
    if verb == "open" and len(args) == 1:
        try:
            url = urlsplit(args[0])
            valid = args[0] == "about:blank" or (
                url.scheme in ("http", "https") and bool(url.hostname)
                and not any(c.isspace() or ord(c) < 32 for c in args[0]))
        except ValueError:
            pass
    elif verb == "snapshot":
        valid = len(args) == len(set(args)) and set(args) <= {"-i", "-c"}
    elif verb == "click":
        valid = len(args) == 1 and ref(args[0])
    elif verb == "fill":
        valid = len(args) == 2 and ref(args[0])
    elif verb in ("press", "eval"):
        valid = len(args) == 1 and bool(args[0])
    elif verb == "scroll":
        valid = (len(args) in (1, 2) and args[0] in ("up", "down", "left", "right")
                 and (len(args) == 1 or (number(args[1]) and 1 <= int(args[1]) <= 20000)))
    elif verb == "wait":
        valid = len(args) == 1 and (ref(args[0]) or (number(args[0]) and int(args[0]) <= ACTION_MS))
    elif verb == "screenshot":
        valid = args in ([], ["--full"])
    elif verb in ("status", "close"):
        valid = not args
    require(valid, "usage", f"Expected: pi-browser SESSION {verb} {GRAMMAR[verb]}".rstrip())
    return key, verb, args


def supported_host():
    # Match the pinned native detector, but refuse inconclusive evidence too.
    require(os.getuid() == os.geteuid() != 0 and os.getgid() == os.getegid(),
            "unsupported_host", "Content requires a non-root, matching real/effective identity.")
    require("CI" not in os.environ, "unsupported_host",
            "Content refused: original CI is present (even empty/false); do not hide it.")
    try:
        for marker in ("/.dockerenv", "/run/.containerenv"):
            try:
                os.lstat(marker)
            except FileNotFoundError:
                continue
            raise Failure("unsupported_host", "Content refused: native container marker detected.")
        cgroup = Path("/proc/1/cgroup").read_text()
        require(bool(cgroup.strip()) and not any(s in cgroup for s in ("docker", "kubepods", "lxc")),
                "unsupported_host", "Content refused: container or inconclusive cgroup evidence.")
    except OSError:
        raise Failure("unsupported_host", "Cannot establish native sandbox host facts; content refused.")


def private_dir(path, create=True):
    if create:
        path.mkdir(mode=0o700, exist_ok=True)
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.geteuid()
            and stat.S_IMODE(info.st_mode) & 0o077 == 0,
            "unsafe_runtime", "Runtime directories must be real, private, user-owned directories.")
    return path


class Context:
    def __init__(self, key):
        require(sys.platform == "linux" and os.getuid() == os.geteuid() != 0
                and os.getgid() == os.getegid(), "unsupported_host", "Requires a normal Linux user.")
        self.session = str(key)
        runtime = private_dir(Path(f"/run/user/{os.geteuid()}"), create=False)
        self.root = private_dir(runtime / "pi-b")
        ipc = self.root
        for part in ("namespaces", NAMESPACE, "run"):
            ipc = private_dir(ipc / part)
        self.scratch = private_dir(self.root / key.hex)
        dirs = {name: private_dir(self.scratch / name)
                for name in ("h", "c", "k", "d", "s", "r", "t", "png")}
        # Native's 103-byte IPC limit; Chromium's Linux sockaddr_un budget.
        require(len(os.fsencode(ipc / f"{key}.sock")) <= 103
                and len(os.fsencode(dirs["t"] / ".org.chromium.Chromium.XXXXXX/SingletonSocket")) <= 107,
                "runtime_path_too_long", "Runtime paths exceed the native/Chromium Unix socket budget.")
        self.images = dirs["png"]
        self.env = {
            "PATH": PATH, "LANG": "C.UTF-8", "HOME": str(dirs["h"]),
            "XDG_CONFIG_HOME": str(dirs["c"]), "XDG_CACHE_HOME": str(dirs["k"]),
            "XDG_DATA_HOME": str(dirs["d"]), "XDG_STATE_HOME": str(dirs["s"]),
            "XDG_RUNTIME_DIR": str(dirs["r"]), "TMPDIR": str(dirs["t"]),
            "SSL_CERT_FILE": CA, "NIX_SSL_CERT_FILE": CA,
            "AGENT_BROWSER_SOCKET_DIR": str(self.root),
            "AGENT_BROWSER_DEFAULT_TIMEOUT": str(ACTION_MS),
            "AGENT_BROWSER_RESTORE_SAVE": "never", "AGENT_BROWSER_AUTOSAVE_INTERVAL_MS": "0",
        }
        if "CI" in os.environ:
            self.env["CI"] = os.environ["CI"]  # Neutral cleanup must not conceal it either.
        self.prefix = [AGENT, "--config", CONFIG, "--namespace", NAMESPACE,
                       "--session", self.session, "--json", "--idle-timeout", "2m"]

    def native(self, command, content=False, batch=False):
        prefix = self.prefix + (["--headed", "false", "--executable-path", CHROMIUM] if content else [])
        argv = prefix + (["batch", "--bail"] if batch else command)
        try:
            result = subprocess.run(argv, input=json.dumps([command]) if batch else None,
                                    text=True, capture_output=True, env=self.env, cwd=self.scratch,
                                    timeout=CLI_SECONDS)
        except subprocess.TimeoutExpired:
            raise Failure("native_timeout", "Native CLI deadline expired; no wrapper replay was attempted.")
        except UnicodeError:
            raise Failure("native_response", "Native CLI returned invalid text.")
        try:
            reply = json.loads(result.stdout)
            if batch:
                require(isinstance(reply, list) and len(reply) == 1, "native_response", "Invalid native batch reply.")
                reply = reply[0]
            require(isinstance(reply, dict), "native_response", "Invalid native reply.")
            require(reply.get("success") is True and result.returncode == 0,
                    "native_failed", "Native operation failed; inspect page/session before retrying.")
            data = reply.get("result" if batch else "data")
            require(isinstance(data, dict), "native_response", "Native result was not an object.")
            return data
        except (ValueError, UnicodeError):
            raise Failure("native_response", "Native CLI returned unreadable JSON.")

    def status(self):
        data = self.native(["session", "info"])
        require(type(data.get("active")) is bool, "native_response", "Missing native liveness fact.")
        if not data["active"]:
            return {"state": "absent", "browser": False}
        runtime = data.get("runtime")
        if (not isinstance(runtime, dict) or data.get("runtimeError")
                or type(runtime.get("browserLaunched")) is not bool):
            return {"state": "unreachable", "browser": False}
        return {"state": "running", "browser": runtime["browserLaunched"]}

    def close(self):
        before = self.status()
        if before["state"] == "absent":
            return {"already_absent": True}
        require(before["state"] == "running", "session_unreachable",
                "Session is unreachable; no PID/signal fallback is permitted.")
        reply = self.native(["close"])
        require(reply.get("closed") is True, "close_failed", "Native close was not confirmed.")
        # Native closes before exiting its daemon. This is not a signal fallback.
        for _ in range(10):
            if self.status()["state"] == "absent":
                return {"already_absent": False}
            time.sleep(0.1)
        raise Failure("close_unconfirmed", "Native close replied but daemon exit is unconfirmed.")

    def stream_off(self, prepare=False):
        state = self.native(["stream", "status"], content=True)
        if prepare and state.get("enabled") is True:
            self.native(["stream", "disable"], content=True)
            state = self.native(["stream", "status"], content=True)
        require(state.get("enabled") is False and state.get("port", False) is None
                and state.get("screencasting") is False,
                "stream_not_disabled", "Streaming is not confirmed disabled; session will be closed.")

    def perform(self, verb, args):
        if verb != "open":
            state = self.status()
            require(state["state"] != "unreachable", "session_unreachable", "Session is unreachable; do not replay actions.")
            require(state["state"] == "running" and state["browser"], "session_absent",
                    "No existing browser; explicit open creates fresh state after close/idle expiry.")
        dispatched = False
        try:
            self.stream_off(prepare=True)
            command = [verb, *args]
            image = None
            if verb == "eval":
                # Also avoid eval's own --stdin/--base64 interpretation of page source.
                command = ["eval", "--base64", base64.b64encode(args[0].encode()).decode()]
            if verb == "screenshot":
                fd, name = tempfile.mkstemp(prefix="shot-", suffix=".png", dir=self.images)
                os.close(fd)
                image = Path(name)
                command = [verb, name, *args]
            dispatched = True
            data = self.native(command, content=True, batch=True)
            self.stream_off()
            if verb == "open":
                require(isinstance(data.get("url"), str) and isinstance(data.get("title"), str),
                        "native_response", "Missing navigation result.")
                return {"url": data["url"], "title": data["title"]}
            if verb == "snapshot":
                require(isinstance(data.get("snapshot"), str), "native_response", "Missing snapshot text.")
                return {"text": data["snapshot"]}
            if verb == "eval":
                require("result" in data, "native_response", "Missing page evaluation value.")
                return {"value": data["result"]}
            if image is not None:
                info = image.lstat()
                require(stat.S_ISREG(info.st_mode) and info.st_uid == os.geteuid()
                        and stat.S_IMODE(info.st_mode) == 0o600 and info.st_size > 24,
                        "invalid_image", "Screenshot is not a private regular PNG file.")
                with image.open("rb") as png:
                    require(png.read(8) == b"\x89PNG\r\n\x1a\n", "invalid_image", "Screenshot has no PNG signature.")
                return {"path": str(image)}
            return {"done": True}
        except (Failure, OSError) as exc:
            try:
                self.close()
                cleanup = "Scoped native close confirmed."
            except (Failure, OSError):
                cleanup = "Scoped close unconfirmed; native idle expiry remains best effort."
            if dispatched:
                raise Failure("outcome_unknown", "Action was dispatched; outcome is unknown. Do not blindly replay. " + cleanup)
            if isinstance(exc, Failure):
                raise Failure(exc.code, exc.message + " " + cleanup)
            raise Failure("runtime_io", "Private runtime I/O failed. " + cleanup)


def main():
    os.umask(0o077)
    if sys.argv[1:] == ["--help"]:
        print("Usage: pi-browser SESSION OPERATION (canonical lowercase UUID v4)\n" + "\n".join(
            f"  {verb} {args}".rstrip() for verb, args in GRAMMAR.items()))
        return 0
    session = None
    try:
        key, verb, args = parse(sys.argv[1:])
        session = str(key)
        if verb not in ("status", "close"):
            supported_host()
        context = Context(key)
        result = context.status() if verb == "status" else context.close() if verb == "close" else context.perform(verb, args)
        print(json.dumps({"ok": True, "session": session, "result": result}, ensure_ascii=True))
        return 0
    except (Failure, OSError) as exc:
        code, message = (exc.code, exc.message) if isinstance(exc, Failure) else ("runtime_io", "Private runtime or executable unavailable; no fallback attempted.")
        print(json.dumps({"ok": False, "session": session, "code": code, "message": message}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
