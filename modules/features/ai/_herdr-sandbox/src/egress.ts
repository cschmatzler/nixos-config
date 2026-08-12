import net from "node:net";

const MAX_HEADER_BYTES = 64 * 1024;
const MAX_CREDENTIAL_BODY_BYTES = 16 * 1024 * 1024;
const HEADER_TIMEOUT_MS = 10_000;

/** One exact hostname and TCP port available through the sandbox proxy. */
export type AllowedEndpoint = {
  readonly host: string;
  readonly port: number;
};

/** Configuration for the exact endpoint gate in front of the nono proxy. */
export type EgressGateConfig = {
  readonly listenHost: string;
  readonly listenPort: number;
  readonly proxyHost: string;
  readonly proxyPort: number;
  readonly proxyToken: string;
  readonly credentialToken: string;
  readonly credentialPaths: ReadonlyArray<string>;
  readonly allowedEndpoints: ReadonlyArray<AllowedEndpoint>;
};

type ParsedTarget = {
  readonly host: string;
  readonly port: number;
};

type ParsedRequest = {
  readonly _tag: "tunnel" | "single" | "credential";
  readonly contentLength: number;
};

function parsePort(input: string): number | undefined {
  const parsed = Number(input);
  return Number.isInteger(parsed) && parsed >= 1 && parsed <= 65_535 ? parsed : undefined;
}

function parseConnectTarget(target: string): ParsedTarget | undefined {
  try {
    const parsed = new URL(`http://${target}`);
    const port = parsePort(parsed.port);
    if (
      port === undefined ||
      parsed.username !== "" ||
      parsed.password !== "" ||
      parsed.pathname !== "/" ||
      parsed.search !== "" ||
      parsed.hash !== ""
    ) {
      return undefined;
    }
    return { host: parsed.hostname.toLowerCase(), port };
  } catch {
    return undefined;
  }
}

function parseAbsoluteTarget(target: string): ParsedTarget | undefined {
  try {
    const parsed = new URL(target);
    if (parsed.protocol !== "http:" || parsed.username !== "" || parsed.password !== "") {
      return undefined;
    }
    const port = parsed.port === "" ? 80 : parsePort(parsed.port);
    return port === undefined
      ? undefined
      : { host: parsed.hostname.toLowerCase(), port };
  } catch {
    return undefined;
  }
}

function parseHostHeader(input: string): ParsedTarget | undefined {
  try {
    const parsed = new URL(`http://${input}`);
    if (
      parsed.username !== "" ||
      parsed.password !== "" ||
      parsed.pathname !== "/" ||
      parsed.search !== "" ||
      parsed.hash !== ""
    ) {
      return undefined;
    }
    const port = parsed.port === "" ? 80 : parsePort(parsed.port);
    return port === undefined
      ? undefined
      : { host: parsed.hostname.toLowerCase(), port };
  } catch {
    return undefined;
  }
}

function endpointKey(endpoint: ParsedTarget): string {
  return `${endpoint.host}:${endpoint.port}`;
}

function headerValues(lines: ReadonlyArray<string>, name: string): ReadonlyArray<string> {
  const prefix = `${name.toLowerCase()}:`;
  return lines
    .slice(1)
    .filter((line) => line.toLowerCase().startsWith(prefix))
    .map((line) => line.slice(line.indexOf(":") + 1).trim());
}

function parseContentLength(lines: ReadonlyArray<string>): number | undefined {
  if (headerValues(lines, "transfer-encoding").length !== 0) return undefined;
  const values = headerValues(lines, "content-length");
  if (values.length === 0) return 0;
  if (values.length !== 1 || !/^[0-9]+$/.test(values[0] ?? "")) return undefined;
  const length = Number(values[0]);
  return Number.isSafeInteger(length) && length <= MAX_CREDENTIAL_BODY_BYTES
    ? length
    : undefined;
}

function pathMatches(pathname: string, allowedPath: string): boolean {
  return pathname === allowedPath || pathname.startsWith(`${allowedPath}/`);
}

function parseRequest(
  header: Buffer,
  allowed: ReadonlySet<string>,
  credentialPaths: ReadonlyArray<string>,
  credentialToken: string,
  listenPort: number,
): ParsedRequest | undefined {
  const lines = header.toString("ascii").split("\r\n");
  const firstLine = lines[0];
  if (firstLine === undefined) return undefined;
  const match = /^(CONNECT|[A-Z]+) ([^ ]+) HTTP\/1\.[01]$/.exec(firstLine);
  if (match === null) return undefined;
  const [, method, target] = match;
  if (method === undefined || target === undefined) return undefined;

  if (method === "CONNECT") {
    const connectTarget = parseConnectTarget(target);
    return connectTarget !== undefined && allowed.has(endpointKey(connectTarget))
      ? { _tag: "tunnel", contentLength: 0 }
      : undefined;
  }

  const contentLength = parseContentLength(lines);
  if (contentLength === undefined) return undefined;
  const hosts = headerValues(lines, "host");
  if (hosts.length !== 1) return undefined;
  const hostTarget = parseHostHeader(hosts[0] ?? "");

  if (target.startsWith("/")) {
    const localHost = hostTarget?.host === "127.0.0.1" || hostTarget?.host === "localhost";
    const localPort = hostTarget?.port === listenPort;
    let parsedPath: URL;
    try {
      parsedPath = new URL(target, `http://127.0.0.1:${listenPort}`);
    } catch {
      return undefined;
    }
    const authorization = headerValues(lines, "authorization");
    return localHost &&
        localPort &&
        authorization.length === 1 &&
        authorization[0] === `Bearer ${credentialToken}` &&
        credentialPaths.some((path) => pathMatches(parsedPath.pathname, path))
      ? { _tag: "credential", contentLength }
      : undefined;
  }

  if ((method !== "GET" && method !== "HEAD") || contentLength !== 0) return undefined;
  const absoluteTarget = parseAbsoluteTarget(target);
  return absoluteTarget !== undefined &&
      hostTarget !== undefined &&
      endpointKey(hostTarget) === endpointKey(absoluteTarget) &&
      allowed.has(endpointKey(absoluteTarget))
    ? { _tag: "single", contentLength: 0 }
    : undefined;
}

function proxyHeader(
  header: Buffer,
  proxyToken: string,
  closeConnection: boolean,
  credentialRequest: boolean,
): Buffer {
  const lines = header.toString("ascii").split("\r\n");
  const filtered = lines.filter((line, index) => {
    if (index === 0) return true;
    const lower = line.toLowerCase();
    return line !== "" &&
      !lower.startsWith("proxy-authorization:") &&
      (!credentialRequest || !lower.startsWith("authorization:")) &&
      (!closeConnection || !lower.startsWith("connection:"));
  });
  const authorization = Buffer.from(`nono:${proxyToken}`).toString("base64");
  return Buffer.from([
    ...filtered,
    `Proxy-Authorization: Basic ${authorization}`,
    ...(credentialRequest ? [`Authorization: Bearer ${proxyToken}`] : []),
    ...(closeConnection ? ["Connection: close"] : []),
    "",
    "",
  ].join("\r\n"), "ascii");
}

function reject(socket: net.Socket, status: 403 | 431 | 502, reason: string): void {
  socket.end(
    `HTTP/1.1 ${status} ${reason}\r\n` +
      "Connection: close\r\n" +
      "Content-Length: 0\r\n\r\n",
  );
}

/**
 * Start a TCP gate that admits only exact host-and-port proxy requests before
 * forwarding them to nono for DNS, private-address, and credential policy.
 *
 * @param config - Listener, upstream proxy, credential routes, and endpoint configuration.
 * @returns The listening server. Its owner is responsible for closing it.
 */
export function startEgressGate(config: EgressGateConfig): net.Server {
  const allowed = new Set(config.allowedEndpoints.map(endpointKey));
  const server = net.createServer((client) => {
    let buffered = Buffer.alloc(0);
    client.setTimeout(HEADER_TIMEOUT_MS, () => client.destroy());

    const onData = (chunk: Buffer): void => {
      buffered = Buffer.concat([buffered, chunk]);
      const headerEnd = buffered.indexOf("\r\n\r\n");
      if (headerEnd === -1) {
        if (buffered.length > MAX_HEADER_BYTES) {
          client.off("data", onData);
          reject(client, 431, "Request Header Fields Too Large");
        }
        return;
      }
      if (headerEnd + 4 > MAX_HEADER_BYTES) {
        client.off("data", onData);
        reject(client, 431, "Request Header Fields Too Large");
        return;
      }

      client.off("data", onData);
      client.pause();
      const headerLength = headerEnd + 4;
      const request = parseRequest(
        buffered.subarray(0, headerLength),
        allowed,
        config.credentialPaths,
        config.credentialToken,
        config.listenPort,
      );
      const initialBody = buffered.subarray(headerLength);
      if (
        request === undefined ||
        request._tag === "single" && initialBody.length !== 0 ||
        request._tag === "credential" && initialBody.length > request.contentLength
      ) {
        reject(client, 403, "Forbidden");
        return;
      }

      const proxy = net.createConnection(config.proxyPort, config.proxyHost);
      proxy.once("connect", () => {
        client.setTimeout(0);
        proxy.write(proxyHeader(
          buffered.subarray(0, headerLength),
          config.proxyToken,
          request._tag !== "tunnel",
          request._tag === "credential",
        ));
        if (initialBody.length !== 0) proxy.write(initialBody);
        buffered = Buffer.alloc(0);

        if (request._tag === "tunnel") {
          client.pipe(proxy);
        } else {
          let remaining = request.contentLength - initialBody.length;
          client.on("data", (bodyChunk: Buffer) => {
            if (bodyChunk.length > remaining) {
              client.destroy();
              proxy.destroy();
              return;
            }
            remaining -= bodyChunk.length;
            proxy.write(bodyChunk);
            if (remaining === 0) client.pause();
          });
          if (remaining > 0) client.resume();
        }
        proxy.pipe(client);
      });
      proxy.once("error", () => {
        reject(client, 502, "Bad Gateway");
      });
      client.once("error", () => proxy.destroy());
      client.once("close", () => proxy.destroy());
    };

    client.on("data", onData);
    client.on("error", () => client.destroy());
  });
  server.listen(config.listenPort, config.listenHost);
  return server;
}
