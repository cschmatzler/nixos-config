# Faster alternatives to Docker Sandboxes for Herdr linked-worktree sandboxes

- Status: research, decision-oriented
- Date: 2026-08-11
- Scope: `modules/features/ai/herdr-sandbox.nix`, `modules/features/ai/_herdr-sandbox/**`,
  ADR [0001](../adr/0001-docker-sandboxes-herdr-workspaces.md)
- Host under evaluation: Tahani — Linux 6.18.41 x86_64, NixOS, `/dev/kvm` present,
  LSMs `capability,landlock,yama,bpf,ima`, cgroup v2 with `cpu memory pids` delegated to
  the user session (all *measured locally, 2026-08-11*)

## 0. Evidence labels

Every latency or capability claim below carries one of four labels. Nothing is estimated
into a number.

| Label | Meaning |
| --- | --- |
| **measured** | Run on Tahani on 2026-08-11, command and run count given |
| **documented** | Stated by the project that owns the code, link + access date given |
| **inferred** | Deduced from documented mechanism, marked as a deduction |
| **unknown** | Not established; explicitly flagged rather than guessed |

All sources were accessed **2026-08-11**.

---

## 1. What the current system actually guarantees

Extracted from the code, not from the ADR prose. These are the acceptance criteria any
replacement is measured against.

| # | Guarantee | Where it lives |
| --- | --- | --- |
| **R1** | One persistent environment per linked worktree, deterministically named `herdr-<sha256(checkout)[0:20]>`, surviving pane close and sandbox restart | `shell.fish:30-31`, `sbx create --clone` |
| **R2** | Every pane attaches to **the same** environment with a real PTY — Fish, Nvim and TUIs run inside one microVM, so panes share the process namespace and can see, signal and manage each other's processes. (Each pane's Fish *job table* is per-shell, as on any host: `jobs`/`fg`/`bg` do not cross panes. What is shared is the process namespace, not shell job control.) | `shell.fish:176` (`sbx exec -it`), one microVM per workspace |
| **R3** | Private writable clone, bind-mounted **at the host checkout path**, so Fish/Devenv/Nvim resolve an identical project root; commits leave via the `sbx`-managed remote | `shell.fish:76-87`, `herdr-sandbox-fish:12-26` |
| **R4** | Host `/nix` plus four selected caches mounted read-only, nothing else | `shell.fish:55-64` |
| **R5** | Scoped host Herdr broker: host socket never mounted; 64-hex per-workspace capability; scope re-derived from live Herdr state per request; out-of-scope rejected; responses filtered; guest sees a normal Unix socket | `src/daemon.ts`, `src/herdr.ts`, `src/guest/herdr-relay.ts` |
| **R6** | Credentials in guest-private storage; nothing mounted back to the host; GitHub/Supermemory as `sbx` secrets with placeholder injection | `shell.fish:120-147`, `kit/spec.yaml` |
| **R7** | Default-deny outbound with an explicit host:port allowlist (31 entries) | `kit/spec.yaml:10-43` |
| **R8** | Resource limits: 4 CPUs, 8 GiB RAM, 20 GiB root + 20 GiB docker disk | `herdr-sandbox.nix:19-20,41-42` |
| **R9** | Full dev tooling: host Nix profile + Home Manager generation mirrored into the guest, Devenv, `.agents/resume`/`.agents/setup`, **and `apt`** (Ubuntu guest) | `herdr-sandbox-fish:3-5,32-39,77-96`, `kit/spec.yaml:33-34` |
| **R10** | No unsafe host-shell fallback for linked worktrees — every failure path is `exit 1`; only top-level workspaces intentionally get the host shell | `shell.fish:27-29,84,89,146` |
| **R11** | **Guest kernel boundary.** The guest has passwordless `sudo` (used for the bind mount), so guest root is assumed reachable; what protects the host is the microVM, not in-guest privilege separation | `herdr-sandbox-fish:13-22`; sbx is a "microVM sandbox" (documented) |
| **R12** | Herdr `agent.start` works in sandboxed panes — the pane's host-side foreground process must be *named* like a shell | `sbx-package.nix:58-63` |
| **R13** | A routine pane attach costs exactly one `sbx exec`; provisioning is stamped away | `shell.fish:47-52,140-147` |

R2, R3, R11 and R9-with-`apt` are the four that eliminate most candidates.

---

## 2. Where the latency actually is

This is the single most important finding, and it changes the question.

### 2.1 Upstream report #429 (the user's own issue)

[docker/sbx-releases#429](https://github.com/docker/sbx-releases/issues/429) — open, **zero
comments**, filed 2026-08-11T16:19:53Z by `cschmatzler`. Retrieved via
`gh api repos/docker/sbx-releases/issues/429`, accessed 2026-08-11.

Reported measurements (v0.38.0, Linux x86_64, headless NixOS, no keychain, KVM):

- `sbx version` ≈ **3.4 s** wall, ≈ 2.9 s user CPU
- `sbx exec` scales **≈ 0.35 s of scrypt per stored secret per invocation**
- `sbx exec <running-sandbox> true` with a dozen sandboxes carrying per-sandbox secrets:
  **≈ 17 s of user CPU**; strace showed **50 age/scrypt operations for one exec with 28
  stored secrets**

Root cause, from a SIGQUIT goroutine dump quoted in the issue:

```
settingskit engine.(*Manager).startMonitors
  → startFFRemoteMonitor → refreshFFRemote            # synchronous remote FF refresh at CLI startup
    → platform.unleashEvalContext → resolveIdentity
      → readIdentityFromAuthStore
        → authkit/dockerhub.(*verifier).GetDefaultProfileAccessToken
          → secrets-engine/store/posixage.(*fileStore).Get
            → filippo.io/age.(*ScryptIdentity).unwrap
              → scrypt.Key(..., N=0x40000, ...)       # ~0.35 s CPU per entry, every invocation
```

Three compounding defects, per the issue: the Unleash feature-flag refresh is **synchronous
in CLI startup** (even `sbx version` waits for it); identity resolution scrypt-decrypts the
posixage auth store on **every** invocation with no cross-process cache; and on Linux the
auth store is pinned to the posixage file backend
(`sandboxlib/secretsstore/posixage_local.go`), so a running `org.freedesktop.secrets`
service is never consulted — no keychain escape hatch on headless Linux. The issue also
notes the posixage store passphrase is the hardcoded string `"secretpass"`, so the
N=2^18 scrypt work buys nothing over file permissions.

### 2.2 The cost is in the CLI, not the microVM

`sandboxd` is a **long-lived daemon** with a Unix socket — *measured*:

```
$ sbx daemon status
Status: running
Socket: ~/.local/state/sandboxes/sandboxes/sandboxd/sandboxd.sock
```

The binary embeds containerd plugin identifiers and an `io.containerd.nerdbox.*` shim
(*measured*, `strings` over `sbx-unwrapped` 0.38.0). So for a **running** sandbox the VM is
already warm and the guest is already booted; the multi-second pane attach is pure
client-side startup tax. That means:

> The current latency problem is a Docker CLI bug, not a property of microVMs.
> Replacing the *isolation technology* is not required to fix it, and doing so would
> trade away R11 to solve a problem that lives one layer up.

### 2.3 Measured on Tahani, 2026-08-11

Store state at measurement time: **2 global secret entries**, 21 sandboxes (1 running) —
*measured*. So these numbers reflect the ~3 s fixed floor, not the per-secret tax.

These are **no-op process/VM overheads**, not prompt-ready cold starts: each row is the cost
of getting a trivial command to run, and the commands differ in kind across rows. Nothing
here measures time-to-first-Fish-prompt for a real workspace (§7 benchmarks 1 and 3).

| Command | Mean | Runs | Label |
| --- | --- | --- | --- |
| `sbx version` | **3.295 s ± 0.052** (user 2.895, sys 0.402) | 3 + 1 warmup | measured |
| `sbx version` (repeat) | 3.517 s ± 0.340 | 3 + 1 warmup | measured |
| `sbx exec -u agent <running> true` | **4.799 s ± 0.035** (user 4.332, sys 0.400) | 3 + 1 warmup | measured |
| `sbx exec -u agent <running> true` (repeat) | 5.220 s ± 0.740 | 3 + 1 warmup | measured |
| `nono wrap --silent --allow-cwd --read /nix --read /run/current-system --block-net -- true` | **4.9 ms ± 1.9** | 20 + 3 warmups | measured |
| `nono run --silent --no-audit --trust-override … -- true` (supervised) | **22.1 ms ± 2.9** | 20 + 3 warmups | measured |
| `srt` (sandbox-runtime 0.0.71), empty domain list, no writable dirs | **287.4 ms ± 55.6** | 20 + 3 warmups | measured |
| `bwrap` cold start, full mount set → `true` | **4.1 ms ± 1.7** | 20 + 3 warmups | measured |
| `nsenter --preserve-credentials --user --mount --pid --uts --ipc` into a **live** bwrap sandbox → `true` | **792.7 µs ± 632.1** | 20 + 3 warmups | measured |

hyperfine warns below 5 ms that shell-calibration limits accuracy; the sub-5 ms figures are
order-of-magnitude, not precise.

### 2.4 An immediately available 1.9 s win

`SBX_NO_TELEMETRY` exists in the 0.38.0 binary (*measured* — found by `strings`, alongside
`SBX_MCP_URL`, `SBX_CRED_*`, `DOCKER_SANDBOXES_*`). It is **undocumented** in the CLI help.
Setting it roughly halves the fixed cost — *measured*, hyperfine, 3 runs + 1 warmup each:

| Command | Default | `SBX_NO_TELEMETRY=1` | Delta |
| --- | --- | --- | --- |
| `sbx version` | 3.517 s ± 0.340 | **1.778 s ± 0.100** | −1.74 s (1.98×) |
| `sbx exec -u agent <running> true` | 5.220 s ± 0.740 | **3.355 s ± 0.035** | −1.87 s (1.56×) |

This is a one-line change in `herdr-sandbox.nix` and it does **not** fix the root cause in
#429 (the identity/scrypt path still runs — hence the residual ~3.3 s). It is undocumented,
so it can regress on any upgrade; a pin plus a smoke check is warranted.

---

## 3. Process confinement vs containers vs VMs

The three tiers are not interchangeable, and the distinction decides most of this
evaluation.

**Process confinement** (nono, `srt`, raw Landlock/seccomp): the sandboxed process is an
ordinary host process with the host kernel, host PID namespace and host filesystem
paths. nono states its boundary explicitly:

> "nono's trust boundary is agent containment — restricting what the sandboxed child can
> access — not guest/host isolation between same-user processes. If an attacker has
> arbitrary code execution as your user, they already own all your processes and files …
> If you need stronger isolation between same-user processes … run nono inside a container
> or microVM."
> — [Security Model](https://github.com/nolabs-ai/nono/blob/main/docs/cli/internals/security-model.mdx), accessed 2026-08-11

Landlock additionally **cannot** mediate `chdir`, `stat`, `flock`, `chmod`, `chown`,
`setxattr`, `utime`, `fcntl`, `access`, and "sandboxed threads … cannot modify filesystem
topology, whether via `mount(2)` or `pivot_root(2)`"
([kernel docs](https://docs.kernel.org/userspace-api/landlock.html), accessed 2026-08-11).
The last clause is the structural reason nono cannot deliver R3.

**Containers** (bubblewrap, Podman, nspawn): namespaces give a private mount table, a
private PID view, and a private UID map — one shared kernel. bubblewrap is explicit that it
is a *construction kit*, not a boundary:

> "bubblewrap is not a complete, ready-made sandbox with a specific security policy. …
> the level of protection between the sandboxed processes and the host system is entirely
> determined by the arguments passed to bubblewrap."
> — [bubblewrap README](https://github.com/containers/bubblewrap#sandbox-security), accessed 2026-08-11

**VMs / microVMs** (sbx today, Firecracker, cloud-hypervisor, Gondolin, Microsandbox,
microvm.nix): a separate guest kernel, so the host attack surface reduces to the VMM and
its virtio devices. microvm.nix puts the case plainly:

> "It is still one shared Linux kernel with a huge attack surface. Virtual machines on the
> other hand run their own OS kernel, reducing the attack surface to the hypervisor and its
> device drivers."
> — [microvm.nix intro](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/intro.md), accessed 2026-08-11

Only the third tier preserves **R11**. Everything in tiers one and two loses it, and no
amount of policy tuning changes that.

---

## 4. Candidates

### 4.1 nono — `nolabs-ai/nono`

Apache-2.0, 3,615 stars, created 2026-01-31, pushed 2026-08-11 (*measured* via GitHub API).
Packaged in nixpkgs at **0.71.0** (*measured*: `nix eval nixpkgs#nono.version`). Built by
the Sigstore team; OpenSSF Best Practices badge; pre-1.0 with an explicit API-stability
caveat in the README.

**Mechanism.** Landlock LSM (Linux) / Seatbelt (macOS) as an irreversible floor, plus
optional `seccomp-notify` (`SECCOMP_RET_USER_NOTIF` on `openat`/`openat2`) for supervisor-
mediated capability expansion via `SECCOMP_IOCTL_NOTIF_ADDFD` fd injection. Egress goes
through an HTTP/CONNECT + reverse proxy in the *unsandboxed* supervisor; the child is
restricted to `localhost:<port>` by Landlock ABI v4+ per-port TCP rules and authenticated
with a 256-bit session token. "no daemon, no container, no VM, and no disk space usage"
(README). Verified feature surface in 0.71.0 (*measured*, `nono --help` / `nono run --help`):
`run`/`shell`/`wrap`, `ps`/`attach`/`detach`/`stop`/`inspect`, `--memory`/`--max-processes`,
`--allow-domain`/`--network-profile`/`--block-net`, `--credential`, `--sandbox-policy
auto|landlock|external`, `--allow-unix-socket*`, `proxy` (standalone).

**What nono does better than the status quo:**

- **Latency.** 4.9 ms direct / 22.1 ms supervised vs 4.8 s per pane attach (*measured*) —
  roughly three orders of magnitude.
- **Credentials (R6+).** The real key never enters the child: "The child sees
  `OPENAI_BASE_URL=http://127.0.0.1:<port>/openai` … The proxy injects `Authorization:
  Bearer sk-…` when forwarding" (Security Model). Today the repo *copies* `auth.json`,
  `mcp-oauth`, and `.claude/.credentials.json` into the guest — nono's model is strictly
  stronger.
- **Egress (R7+).** Domain allowlists with per-path L7 rules
  (`--allow-domain 'https://github.com/org/**'`), DNS-rebinding protection (post-resolution
  link-local and cloud-metadata denial), and per-tool credential scoping via
  `command_policies`. Strictly richer than the kit's flat `host:port` list.
- **`/nix` read-only (R4).** `--read /nix` — trivially, with no mount plumbing.
- **Resource limits (R8, partial).** cgroup v2 `memory.max` + `memory.swap.max=0` +
  `memory.oom.group=1`, and `pids.max`; fail-closed if the controller is not delegated. On
  Tahani `cpu memory pids` **are** delegated (*measured*), so this works. **No CPU or I/O
  cap** — "It does not yet limit CPU or I/O — for those, reach for a container"
  ([containers doc](https://github.com/nolabs-ai/nono/blob/main/docs/cli/internals/containers.mdx)).

**What nono structurally cannot preserve:**

- **R2 — many panes, one environment. This is the disqualifier for a drop-in.** A session
  is one PTY owned by the supervisor, and attach is exclusive: "If another client is already
  attached, the supervisor rejects the attach attempt"
  ([session-lifecycle](https://github.com/nolabs-ai/nono/blob/main/docs/cli/features/session-lifecycle.mdx)).
  There is **no `nono exec <session>`** subcommand in 0.71.0 (*measured*, `nono --help`), so
  a second pane cannot spawn a process inside an existing session. The only shape available
  is *N independent sessions with the same profile* — N supervisors, N policies, N process
  trees. What is lost is the shared process namespace — "kill the dev server I started in
  pane 1 from pane 3" no longer refers to one reachable set of processes.
- **R3 — private clone at the checkout path.** Landlock cannot change the mount table
  (kernel docs, above), and nono declines mount namespaces on purpose: "Building a core
  security boundary on a mechanism that distro maintainers are actively restricting is
  fragile" (Security Model, *Why not mount namespaces?*). A private clone can exist at a
  *different* real path, but the path-identity trick that makes Devenv/Fish/Nvim agree
  disappears.
- **R11 — the kernel boundary.** Stated by the project (§3). Also: `stat`/`access` are not
  trapped, so "the sandboxed child can enumerate filesystem structure … For adversarial
  code, this could enable reconnaissance" (Security Model).
- **R9 with `apt`.** There is no guest distro. `.agents/setup` scripts that `apt-get
  install` would either fail or run against the host. The kit's Ubuntu archive allowlist
  entries and the `pgrep -x apt-get` wait loop (`herdr-sandbox-fish:80-83`) become
  meaningless.
- **PID isolation.** "nono shares the host PID namespace" (containers doc).

**Verdict on the three framings asked for:**

1. **Drop-in `sbx` replacement — no.** R2 and R3 fail structurally, not for want of
   configuration, and R11 is given up. A drop-in would change the product: per-pane
   sandboxes instead of per-workspace environments.
2. **Defense-in-depth — yes, and this is its best immediate use.** nono is designed to
   compose: "Running nono inside a container or microVM gives you both layers
   simultaneously" (Security Model), with a table recommending "a lightweight VM
   (Firecracker, etc) or hardened container runtimes (Edera, Kata) for the outer perimeter,
   and nono inside for fine-grained capability control."
3. **Better redesign foundation — partially, and for one subsystem outright.**
   `nono proxy` standalone is documented for exactly this: "a foreground server with no
   sandboxed child — so you can point external workloads (containers, microVMs) at nono's
   domain filtering and credential injection"
   ([networking](https://github.com/nolabs-ai/nono/blob/main/docs/cli/features/networking.mdx)).
   For **R7** that is a clear upgrade over the kit's flat host:port list, with no change to
   the isolation boundary. For **R6** the picture is narrower: the reverse-proxy /
   phantom-token model applies to clients that talk to an HTTP API through a base URL and a
   header-injectable credential. It has **not** been shown to cover Pi's and Claude's
   browser-OAuth state — `auth.json`, `mcp-auth.json`, `mcp-oauth`, `.claude/.credentials.json`
   are refresh-token and MCP OAuth stores that clients read and *rewrite* locally, not
   single bearer headers. Treat replacing them as a compatibility spike (§6), per credential,
   not as a settled win. `--allow-unix-socket <path>` could also carry the broker RPC over a
   Landlock-scoped socket grant instead of the `host.docker.internal:18743` HTTP hop — with
   the scoped broker and its capability retained (§4.3).

### 4.2 Anthropic sandbox-runtime (`srt`) — `anthropic-experimental/sandbox-runtime`

Apache-2.0, 4,932 stars, pushed 2026-08-11 (*measured*). nixpkgs **0.0.71** (*measured*).
Linux mechanism: **bubblewrap** with bind mounts, network namespace removed entirely, HTTP +
SOCKS5 proxies on the host reached over bind-mounted Unix sockets bridged by `socat`, plus a
static seccomp BPF filter blocking `socket(AF_UNIX, …)` and `io_uring_*`, inside a nested
user+PID namespace with a non-dumpable PID 1 (README, *Implementation Details*).

**Measured 287.4 ms** per invocation — 17× slower than `nono run`, still 17× faster than
`sbx exec`.

Not viable as the environment layer, for three concrete reasons:

- **No session model.** `srt` wraps one command. There is no `ps`/`attach`/persistent
  supervisor, so R1/R2 have no implementation at all.
- **It blocks writes to `.git/config` and `.git/hooks/` unconditionally** — "Always-blocked
  directories: … `.git/hooks/`, `.git/config`" (README). `shell.fish:87` runs
  `git switch --track -c "$branch" "origin/$branch"`, which writes branch config into
  `.git/config`. Direct conflict with R3's workflow.
- **It blocks `AF_UNIX` socket creation by default**, which is precisely what the guest
  Herdr relay does (`herdr-relay.ts:104`, `server.listen(socketPath)`). Allowing it back is
  a config flag, but the README warns `allowUnixSockets` "can inadvertently grant access to
  powerful system services".

Useful as: prior art for the bubblewrap composition in §4.3 (its proxy-over-Unix-socket
design is the cleanest documented way to give a netns-less sandbox a filtered egress path),
and as a per-tool wrapper *inside* whatever environment is chosen.

### 4.3 bubblewrap + `nsenter` + systemd user scope — **the strongest non-VM option**

bubblewrap 0.11.2 is already on Tahani (*measured*). LGPL-2.0+ (`NOASSERTION` in the API;
the repo ships LGPL-2.0-or-later), 8,320 stars, pushed 2026-06-02 (*measured*).

The decisive question was whether a *second, independent pane* can join a *live* bubblewrap
sandbox without root — i.e. whether R2 survives. **It does.** *Measured on Tahani,
2026-08-11:*

```
$ bwrap --unshare-user --unshare-pid --unshare-uts --unshare-ipc --unshare-cgroup \
    --ro-bind /nix /nix --ro-bind /run/current-system /run/current-system \
    --proc /proc --dev /dev --tmpfs /tmp \
    --bind ./fakehome /home/agent --die-with-parent \
    /run/current-system/sw/bin/sleep 60 &

$ nsenter -t $T --preserve-credentials --user --mount --pid --uts --ipc bash -c '…'
home:  .  ..  inside-marker            # private /home/agent visible
touch: cannot touch '/nix/probe': Read-only file system   # R4 enforced
pidns=pid:[4026532875]  visible procs: 6                 # sandbox-private PID view
```

`--preserve-credentials` is required; without it `nsenter` fails with
`setgroups failed: Operation not permitted` (*measured*).

Latency: **4.1 ms ± 1.7** to create, **792.7 µs ± 632.1** to attach (*measured*, 20 runs +
3 warmups) — about **6,000× faster** than the current pane attach.

Requirement coverage: R1 ✓ (a supervisor process holding the namespaces, one per workspace),
**R2 ✓ (measured)**, **R3 ✓** (`--bind private-clone /host/checkout/path` — mount namespaces
are exactly the missing primitive), R4 ✓ (`--ro-bind`), R5 ✓ (bind the broker socket into the
namespace directly, which can retire the `host.docker.internal:18743` HTTP hop — but **the
scoped broker and its per-workspace capability must stay**; see below), R6 ✓ (private home in
a per-workspace directory), **R8 ✓ including CPU**
(`systemd-run --user --scope -p CPUQuota= -p MemoryMax= -p TasksMax=` — `cpu memory pids`
are delegated on Tahani, *measured*), R10 ✓ (fail-closed by construction), R12 ✓ (the pane
wrapper is a host process you name freely — the existing `sbx-pane-shell` trick ports
directly), R13 ✓ (attach is sub-millisecond, so stamping matters less).

Cannot preserve: **R11** (shared kernel — this is the whole trade), **R9's `apt`** (the
guest is NixOS; `.agents/setup` must become Nix/Devenv-shaped), and **R7 on its own** —
bubblewrap has `--unshare-net` (all or nothing) and no domain allowlist. Compose: drop the
netns and hand the sandbox only a Unix socket or a single loopback port to a standalone
`nono proxy` (documented for this) or to `srt`-style HTTP+SOCKS5 proxies.

Also note the README's own warning that bubblewrap is a construction kit, not a policy (§3):
the security of this option is entirely the argument list, and that argument list becomes
*this repo's* responsibility.

**Keep the scoped broker and the capability.** A cheaper transport is not a substitute for
authentication. Under this model the sandbox runs as the same UID as the host broker, so
filesystem permissions and peer credentials cannot distinguish one workspace's sandbox from
another's, nor from any other same-UID process — and `SO_PEERCRED` only proves the UID, which
is uniform here. Everything the broker does today stays load-bearing: the per-workspace
64-hex capability that binds a connection to one `workspaceId`, the re-derivation of scope
from live Herdr state on every request (`daemon.ts:101-108`), the out-of-scope rejection, and
the response filtering. A bound Unix socket removes a network hop; it does not remove the
need to know *which* workspace is asking.

### 4.4 Rootless Podman

Apache-2.0, 32,534 stars, actively developed (*measured*). **Not installed on Tahani**
(*measured*). Would deliver R1 (persistent container), R2 (`podman exec -it` — a real PTY
into a shared PID namespace, semantically closest to `sbx exec`), R3/R4 (volume mounts), R8
(cgroup v2), and R9-with-`apt` (keep an Ubuntu image — the only candidate besides sbx that
preserves the Ubuntu guest).

Against it, from Podman's own [rootless.md](https://github.com/podman-container-tools/podman/blob/main/rootless.md)
(accessed 2026-08-11): `/etc/subuid`+`/etc/subgid` setup required; "No support for setting
resource limits on systems using cgroups v1"; pasta is the default and "connections to that
IP from containers do not work" without explicit configuration; "A standard rootless
configuration only gives containers access to 65536 UIDs and GIDs"; `podman mount` paths
only visible inside the rootless userns.

And the two that matter here: **no built-in egress allowlist** (R7 would need an external
proxy or nftables per container — i.e. the same work as §4.3), and **R11 is still lost**.
The result is most of §4.3's migration cost, none of §4.3's sub-millisecond attach, and a
weaker boundary than today. Ranked below bubblewrap for that reason, above it only if the
`apt` guest is non-negotiable.

### 4.5 systemd-nspawn / NixOS containers

Both are present on Tahani (*measured*: `systemd-nspawn`, `machinectl`). `machinectl shell`
does give a real PTY into a running container — "Open an interactive shell session in a
container or on the local host"
([machinectl.xml](https://github.com/systemd/systemd/blob/main/man/machinectl.xml),
accessed 2026-08-11) — so R2 has an implementation.

Disqualified on two documented points:

- **Privilege.** "`systemd-nspawn` may be invoked with or without privileges. The full
  functionality is currently only available when invoked with privileges. When invoked
  without privileges, various limitations apply" — unprivileged mode supports **only
  disk-image containers** (`--image=`), not `--directory=` unless owned by the foreign UID
  range, and only `--private-network`/`--network-veth`
  ([systemd-nspawn.xml](https://github.com/systemd/systemd/blob/main/man/systemd-nspawn.xml),
  accessed 2026-08-11). A per-workspace, per-user, dynamically created environment is the
  wrong shape for this.
- **NixOS containers are explicitly not an isolation boundary.** "Currently, NixOS
  containers are not perfectly isolated from the host system. This means that a user with
  root access to the container can do things that affect the host. So you should not give
  container root access to untrusted users."
  ([NixOS manual, Container Management](https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/administration/containers.chapter.md),
  accessed 2026-08-11). Since the current guest deliberately *has* root (passwordless sudo,
  R11), this is fatal.

Dismissed.

### 4.6 gVisor

Apache-2.0, 19,059 stars, very actively developed (*measured*). Not installed (*measured*).
A user-space kernel does restore a syscall boundary without a VMM, so R11 is partially
recovered.

Against it: it needs an OCI runtime and an image, so the entire per-workspace lifecycle is
still yours to build; and the filesystem path is the weak spot for a Nix-heavy workload —
"In most cases are dominated by **implementation costs**, due to an internal Virtual File
System (VFS) implementation that needs improvement" and "gVisor introduces a small fixed
overhead for data that transitions across the sandbox boundary … these operations must be
routed through the Gofer"
([gVisor performance guide](https://gvisor.dev/docs/architecture_guide/performance/),
accessed 2026-08-11). `/nix/store` access — which Fish, Nvim, Nix and Devenv drive with many
small opens and stats — is the pattern those documented costs describe, so it is the first
thing to measure; **how much it actually costs here is unknown** and I did not benchmark it.
Startup latency for our configuration: **unknown** (the guide declines to give figures,
attributing observed overhead mostly to Docker). Syscall-compatibility risk for Nix builds and
TUIs: **unknown**.

Not recommended *without* a spike — three unknowns and a per-workspace lifecycle to build —
rather than ruled out on performance grounds I have not established.

### 4.7 Firecracker (raw)

Apache-2.0, 35,996 stars (*measured*). Documented "< 125 ms startup time and a < 5 MiB
memory footprint" per microVM
([FAQ.md](https://github.com/firecracker-microvm/firecracker/blob/main/FAQ.md), accessed
2026-08-11) — that would be a ~40× improvement on cold create while keeping R11.

**Blocked on R4.** Firecracker has no shared-filesystem device: "only 6 emulated devices
are available: virtio-net, virtio-balloon, virtio-block, virtio-vsock, serial console, and a
minimal I8042" (FAQ.md); `docs/design.md` confirms Net/Block/Vsock plus vhost-user block. A
GitHub code search for `virtio-fs` in the repository returns **0 results** (*measured*).
Mounting host `/nix` read-only is therefore impossible; the guest's Nix closure would have
to be baked into a block image per configuration change, and the four cache mounts would
need a different transport entirely. That is a fundamental redesign of R4 and R9, not a
port.

### 4.8 cloud-hypervisor + microvm.nix — the "own the VM stack, natively" option

cloud-hypervisor: 6,093 stars, active (*measured*); it does support virtio-fs, so R4 is
reachable. But a bare VMM is not a sandbox product — building create/attach/persist/policy
on top of it is rebuilding `sbx`.

**microvm.nix** (`microvm-nix/microvm.nix`, MIT, 2,840 stars, pushed 2026-08-10 —
*measured*) is the credible packaging of that idea for this repo, because it is NixOS-native:

- Host module provides `/var/lib/microvms`, `microvm-tap-interfaces@`,
  **`microvm-virtiofsd@`**, and `microvm@` systemd services
  ([host.md](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/host.md)).
- Shares: 9p by default, virtiofs for speed — "Expect `virtiofs` to yield better performance
  over `9p`" — and read-only `/nix/store` sharing is explicitly supported and reduces stage1
  image size "drastically"
  ([shares.html](https://microvm-nix.github.io/microvm.nix/shares.html)). **R4 ✓ with a
  kernel boundary.**
- Caveat that matters for R3: "The Linux overlay filesystem is very picky about the
  filesystems that can be the upper (writable) layer. 9p/virtiofs shares don't work
  currently, so resort to using a volume for that" (same page) — the private writable clone
  must live on a block volume, not on a share.

The interesting second-order effect: a **NixOS** guest would delete most of the current
guest-side complexity. The Home Manager symlink mirror
(`herdr-sandbox-fish:32-39`), the `$HERDR_HOST_PROFILE/bin/fish` indirection, the
`remap-session-home.fish` host-home rewriting, and the `apt-get` wait loop all exist because
the guest is Ubuntu with a foreign `/nix`. Against that: `apt`-based `.agents/setup` breaks
(R9), the host module is **system-level and root-owned** (`/var/lib/microvms`, root systemd
units) rather than per-user, and dynamic per-workspace lifecycle is not its native model
(declarative guests, or the imperative `microvm` command). Highest effort of any option here;
the only one that keeps R11 *and* R4.

### 4.9 Microsandbox

Apache-2.0, 7,257 stars, pushed 2026-08-11 (*measured*). libkrun-based microVM runtime,
runs OCI images, documented "Average boot times under 100 milliseconds"
([README](https://github.com/superradcompany/microsandbox), accessed 2026-08-11). OCI images
mean R9-with-`apt` is reachable.

**Unknown and decision-blocking:** whether it supports multiple concurrent PTY attachments
into one long-lived sandbox (R2), and whether it can bind host `/nix` read-only (R4). I did
not verify either, and will not infer them from "libkrun". Worth a half-day spike *only* if
the microVM boundary (R11) is treated as non-negotiable and microvm.nix's NixOS-guest
constraint is unacceptable.

### 4.10 Gondolin

`earendil-works/gondolin`, Apache-2.0, 1,947 stars, latest release v0.12.0 (2026-05-19),
last push 2026-07-06 (*measured*). Philosophically the closest match to this repo's design:
local microVMs, `attach` to a running VM, SSH support, host-side egress hooks, and secret
injection where "The guest only sees a placeholder token" (README) — the same pattern as
`sbx secret set-custom --placeholder`.

**Not a drop-in under the current host-`/nix` design, but a legitimate redesign candidate
gated on two measurements.** Its documented constraints:

- **Filesystem sharing is a FUSE-to-RPC bridge, not virtio-fs or 9p.** "Each file operation
  becomes an RPC message over virtio-serial. The host `FsRpcService` dispatches it to the
  configured provider(s)"
  ([architecture](https://earendil-works.github.io/gondolin/architecture/), accessed
  2026-08-11), with a guest `sandboxfs` FUSE daemon. Whether that can serve `/nix/store` to
  Fish, Nvim, Nix and Devenv at acceptable latency is **unknown** — the concern is *inferred*
  from the mechanism (per-operation RPC on a metadata-heavy workload) and **no benchmark
  exists, mine or theirs**. This is gate 1: measure `nvim --startuptime` and a `nix build`
  against a Gondolin-mounted store before ruling it in or out. An alternative shape avoids the
  question entirely — bake the guest closure into an image instead of sharing the host store —
  but that is a different design for R4, not the current one.
- **Alpine-only guests**: "The image builder currently only supports Alpine Linux" — R9's
  `apt` path breaks
  ([limitations](https://earendil-works.github.io/gondolin/limitations/)).
- **"HTTP/2 and HTTP/3 are not supported today"** and "QUIC is not supported" — some of the
  allowlisted providers in `kit/spec.yaml` negotiate h2.
- "Gondolin does not provide full VM save/restore" and `/root`, `/tmp`, `/var/cache`,
  `/var/log` are tmpfs-backed and excluded from checkpoints — weaker persistence than R1.
- "ARM64 is the most tested runtime path today. Linux x86_64 `make krun-runner` is covered
  by CI smoke builds" (README) — Tahani is x86_64. This is gate 2: x86_64 must be exercised
  beyond CI smoke builds before it carries a daily workspace.

Its attach model, placeholder secrets and host-side egress hooks are the closest match to
this repo's design of anything surveyed, which is why it stays on the list rather than being
dismissed.

### 4.11 Excluded: hosted SDK sandboxes

E2B, Daytona, Modal, Cloudflare containers and similar hosted sandbox SDKs are out of scope
by construction: the workspace must mount the **host's** `/nix`, the host Home Manager
generation, and four host caches, and must reach a **host-local** Herdr broker over the
loopback interface. A remote sandbox can satisfy none of R3, R4, R5 without shipping the
host's store and its Herdr control plane off-machine. Dismissed without further analysis.

---

## 5. Decision matrix

✓ preserved · ~ partial or needs extra work · ✗ cannot preserve

| | sbx (today) | sbx + `SBX_NO_TELEMETRY` | nono alone | bwrap + nsenter (+`nono proxy`) | rootless Podman | nspawn / NixOS containers | gVisor | Firecracker raw | microvm.nix | Microsandbox | Gondolin | `srt` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **R1** persistent env / workspace | ✓ | ✓ | ~ | ✓ | ✓ | ✓ | ~ | ~ | ✓ | ? | ~ | ✗ |
| **R2** N panes → one env, real PTY | ✓ | ✓ | **✗** | **✓ (measured)** | ✓ | ✓ | ~ | ~ | ✓ | **?** | ✓ | ✗ |
| **R3** private clone at checkout path | ✓ | ✓ | **✗** | ✓ | ✓ | ✓ | ✓ | ~ | ~ (block volume) | ? | ~ | ✗ |
| **R4** host `/nix` + caches read-only | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ~ (gofer, cost unmeasured) | **✗** (no shared-FS device) | ✓ (virtiofs) | ? | ? (FUSE-RPC, unmeasured) | ✓ |
| **R5** scoped host broker | ✓ | ✓ | ✓ (unix-socket grant) | ✓ (direct socket) | ✓ | ✓ | ✓ | ~ (vsock) | ~ (vsock) | ? | ~ | ~ |
| **R6** guest-private credentials | ✓ | ✓ | ✓, **✓✓ for proxyable network keys** (OAuth state unproven) | ✓, ✓✓ same caveat | ✓ | ✓ | ✓ | ✓ | ✓ | ? | ✓✓ for network keys | ✓ |
| **R7** egress allowlist | ✓ | ✓ | **✓✓** (L7 paths) | ✓ only via proxy | ✗ built-in | ✗ built-in | ✗ built-in | ✗ built-in | ~ (nftables) | ? | ✓ | ✓ |
| **R8** CPU + memory + disk caps | ✓ | ✓ | ~ (no CPU/IO) | ✓ (systemd scope) | ✓ | ✓ | ✓ | ✓ | ✓ | ? | ~ | ✗ |
| **R9** tooling incl. `apt` guest | ✓ | ✓ | **✗** | ✗ (NixOS guest) | ✓ | ~ | ✓ | ~ | ✗ (NixOS guest) | ✓ | ✗ (Alpine) | ✗ |
| **R10** no unsafe host-shell fallback | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ? | ✓ | ✓ |
| **R11** guest kernel boundary | ✓ | ✓ | **✗** | **✗** | **✗** | **✗** | ~ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **R12** Herdr `agent.start` | ✓ | ✓ | ~ | ✓ | ✓ | ✓ | ~ | ~ | ~ | ? | ~ | ~ |
| No-op launch overhead (§2.3 — heterogeneous commands, **not** prompt-ready cold start) | — | — | 22 ms (`run`) / 4.9 ms (`wrap`) | 4.1 ms (`bwrap`) | ? | ? | ? | <125 ms VM boot (doc) | ? | <100 ms boot (doc) | ? | 287 ms |
| **Warm pane attach → `true`** | **4.80 s** | **3.36 s** | n/a (no exec-into-session) | **0.79 ms** | ? | ? | ? | n/a | ? | ? | ? | n/a |
| Cold create → interactive prompt | unknown | unknown | unknown | unknown | ? | ? | ? | ? | ? | ? | ? | ? |
| NixOS packaging | unfree binary, hand-wrapped | same | **nixpkgs 0.71.0** | **in nixpkgs / base system** | nixpkgs | base system | nixpkgs | nixpkgs | flake, MIT | not checked | npm | nixpkgs 0.0.71 |
| License | unfree | unfree | Apache-2.0 | LGPL-2.0+ | Apache-2.0 | LGPL/GPL | Apache-2.0 | Apache-2.0 | MIT | Apache-2.0 | Apache-2.0 | Apache-2.0 |

`?` = unknown, not inferred. Latency cells are from §2.3 (measured) or the cited project
docs (documented). The first latency row compares **different kinds of no-op** — a process
launch, a namespace setup, a VM boot — so it bounds per-invocation overhead only; it is not
a cold-start-to-prompt comparison. That measurement does not exist yet for any option and is
§7 benchmark 1.

---

## 6. Ranked recommendation

### 1. Fix the CLI tax; keep the microVM boundary (do this now)

Two changes, hours of work, **zero** guarantees given up:

1. Export `SBX_NO_TELEMETRY=1` in `sandboxShell` (`herdr-sandbox.nix:18-44`). *Measured*
   effect: pane attach 5.220 s → 3.355 s; `sbx version` 3.517 s → 1.778 s. Undocumented, so
   add a smoke check that fails loudly if a future version regresses.
2. Keep pressing #429. The acceptance criteria in the issue (`sbx version` < 200 ms; `exec`
   independent of store size) would take pane attach to roughly the cost of one VM `exec`,
   and it is a client-side fix in Docker's code — the daemon and the guest are already warm
   (§2.2).

Also keep the existing global-secrets discipline (`shell.fish:65-75`): with 2 entries the
per-secret tax is currently negligible, and per-sandbox secrets would reintroduce the ~17 s
pathology from #429 at 21 sandboxes.

### 2. Spike `nono proxy` as defense-in-depth (next)

This is independent of the isolation decision, but it is not configuration-only. Prototype a
standalone host `nono proxy` while retaining the kit policy as the hard boundary. To replace
R7, the guest must be able to reach only the proxy, direct connections must fail even after
proxy environment variables are removed, and every required client/protocol must work through
it. If those gates pass, nono's per-path L7 rules and DNS-rebinding protection would be richer
than the current host:port list without changing R1–R4 or R11.

**R6 also needs a compatibility spike before anything is removed.** The phantom-token model fits
credentials that are a header on an HTTP call to a known base URL — the Supermemory key and
the GitHub token are good candidates, and both are already `sbx` secrets rather than copied
files. It is *not* established that it covers the copied files in `shell.fish:120-147`:
`auth.json`, `mcp-auth.json`, `mcp-oauth` and `.claude/.credentials.json` hold
browser-OAuth and MCP OAuth state that the clients read *and rewrite* locally, including
refresh flows. So: spike each credential against `nono proxy` (does the client honour a base-URL
override? does it survive a token refresh it cannot perform itself?), and delete a copied file
only once its client is shown to work without it. Until then this is an improvement to the
network-key path, not a wholesale replacement of guest credential storage.

Optionally also run `nono run` *inside* the guest around the agent process, which is the
composition nono itself recommends.

### 3. If ms-scale attach is worth the kernel boundary: bubblewrap redesign (prototype behind a flag)

`bwrap` + `nsenter --preserve-credentials` + `systemd-run --user --scope` + standalone
`nono proxy`. *Measured* 4.1 ms create, 0.79 ms attach; preserves R1–R5, R6, R8 (including
the CPU cap that nono lacks), R10, R12, R13. Costs: **R11 entirely**, and `apt` inside
`.agents/setup` (R9). This is a genuine redesign, and it is the only option that beats sbx by
three orders of magnitude on attach while keeping the "one environment, N panes" model —
which nono cannot.

Do this only if the threat model tolerates a shared kernel for agent-generated code. Given
that today's guest already runs with passwordless root *because* the VM is the boundary,
that is a real change in posture, not a refactor.

### 4. If the kernel boundary is non-negotiable and you want to own the stack: microvm.nix

Highest effort, best NixOS fit, keeps R11 and R4 (virtiofs `/nix/store`), and deletes most
of the Ubuntu-guest scaffolding. Blocked by: root/system-level host module, NixOS guests
(no `apt`), and a per-workspace dynamic lifecycle you would build yourself. Treat as a
6-month direction, not a migration.

### Not recommended

- **nono as a drop-in `sbx` replacement** — R2 (exclusive single-client attach, no
  `exec`-into-session) and R3 (no mount namespaces, by design) fail structurally.
- **rootless Podman** — most of option 3's migration cost, none of its latency, no built-in
  egress allowlist, and R11 still lost.
- **nspawn / NixOS containers** — privileged for full function; NixOS manual explicitly
  states container root can affect the host.
- **gVisor** — not without a spike: gofer-mediated `/nix/store` cost, startup latency, and
  syscall compatibility are all unmeasured, and the per-workspace lifecycle is still yours.
- **Firecracker raw** — no shared-filesystem device at all; R4 unreachable without baking
  images.
- **Gondolin — not a drop-in, deferred pending two gates** rather than rejected: measure its
  FUSE-over-virtio-serial store access (unbenchmarked) and exercise x86_64 beyond CI smoke
  builds. Documented blockers stand regardless: Alpine-only guests, no HTTP/2 or QUIC, no full
  VM save/restore.
- **`srt` as the environment layer** — no session model, blocks `.git/config` writes and
  `AF_UNIX` creation.
- **Hosted SDK sandboxes** — cannot mount the host store or reach the host broker.

---

## 7. Benchmark plan for Tahani

Validate the finalists — **(a)** sbx + `SBX_NO_TELEMETRY`, **(b)** bwrap + nsenter +
`nono proxy` — against the same harness. Everything below is `hyperfine --warmup 3
--runs 20` unless noted; report mean ± σ and never a single run.

**Latency**

1. **Cold create** — first pane in a fresh workspace, to a prompt. Not `true`: it must
   include the `.agents/resume` path, since that is what a user feels.
2. **Warm pane attach → `true`** — the §2.3 metric, directly comparable.
3. **Warm pane attach → first Fish prompt.** Needs a PTY harness: drive the pane command
   under `script -qc` (or a small `expect`/`pty` wrapper) and stop the clock on the prompt
   sentinel. `hyperfine` alone cannot measure this.
4. **Nvim startup inside the environment** — `nvim --startuptime` on a real file in the
   private clone; this is the sensitive test for `/nix` access latency (virtiofs vs
   `--ro-bind`).
5. **Nix-heavy work** — `nix build` of a small derivation and `devenv shell -- true`,
   against the read-only host store.
6. **Git on a large repo** — `git status` and `git switch` in the private clone.
7. **Concurrency** — N=1,2,4,8 simultaneous panes: attach latency and interactive
   responsiveness under load, with the resource caps active.

**Correctness and security (pass/fail, not timing)**

8. **R2 identity** — start `sleep 999` in pane 1; assert pane 3 sees it in `ps` and can
   `kill` it. This is the check nono fails. Do **not** assert on `jobs`/`fg`: shell job tables
   are per-shell today too, so a cross-pane `jobs` entry is not a current guarantee.
9. **R3 path identity** — `git rev-parse --show-toplevel`, `pwd -P`, and Devenv's project
   root must all equal the host checkout path in every pane.
10. **R4** — `touch /nix/probe` must fail with EROFS; every host path outside the four caches
    and the private clone must be unreadable.
11. **R7** — an allowlisted host must succeed; a non-allowlisted host must fail; retest with
    `HTTPS_PROXY` unset and with a raw IP to prove the boundary is not env-var-based
    (this is a documented weakness of `srt`'s Linux mode and worth verifying for any
    proxy-based option).
12. **R6** — grep the environment and the guest filesystem for real key material; with
    `nono proxy` only phantom tokens should be present.
13. **R5** — an out-of-scope Herdr method must be rejected by the broker; an in-scope one
    must pass through unchanged, including error bodies.
14. **R8** — a memory hog must be OOM-killed at the cap; a fork bomb must hit `EAGAIN`;
    a spin loop must be CPU-throttled (this last one fails under nono alone).
15. **R12** — Herdr `agent.start` must succeed in a sandboxed pane.

**Hygiene.** Pin `sbx` 0.38.0 for the baseline, record the secret-store entry count and
sandbox count with every run (both affect #429's tax), keep the machine otherwise idle, and
re-run the baseline in the same session as each candidate so numbers are comparable.

---

## 8. Sources

All accessed **2026-08-11**.

**This repository**
- `modules/features/ai/herdr-sandbox.nix`, `_herdr-sandbox/{shell.fish,sbx-package.nix,package.nix,kit/spec.yaml}`,
  `_herdr-sandbox/src/{daemon.ts,herdr.ts,guest/herdr-relay.ts}`,
  `_herdr-sandbox/kit/files/home/.local/{bin/herdr-sandbox-fish,lib/herdr-sandbox/remap-session-home.fish}`
- `docs/adr/0001-docker-sandboxes-herdr-workspaces.md`

**Docker Sandboxes**
- <https://github.com/docker/sbx-releases/issues/429> — the startup-latency report (open, 0 comments)
- <https://docs.docker.com/ai/sandboxes/> — "microVM sandboxes", each with "its own Docker daemon, filesystem, and network"; KVM required on Linux; CLI free, org governance paid
- Local: `sbx --help`, `sbx daemon status`, `strings` over `sbx-unwrapped` 0.38.0

**nono**
- <https://nono.sh> · <https://github.com/nolabs-ai/nono> (Apache-2.0)
- `docs/cli/internals/security-model.mdx` — trust boundaries, Landlock+seccomp layering, attach model, "not guest/host isolation", why not mount namespaces
- `docs/cli/features/session-lifecycle.mdx` — "If another client is already attached, the supervisor rejects the attach attempt"
- `docs/cli/features/resource-limits.mdx` — cgroup v2 `memory.max`/`pids.max`, delegation requirement, fail-closed
- `docs/cli/features/networking.mdx` — proxy modes, network profiles, standalone `nono proxy`
- `docs/cli/features/environment.mdx`, `docs/cli/features/execution-modes.mdx`, `docs/cli/internals/containers.mdx`, `docs/cli/getting_started/installation.mdx`
- Local: `nono --version` (0.71.0), `nono --help`, `nono run --help`, `nono attach --help`, `nono ps --help`

**Anthropic sandbox-runtime**
- <https://github.com/anthropic-experimental/sandbox-runtime> (Apache-2.0) — bubblewrap on Linux, netns removed, proxies over Unix sockets, seccomp `AF_UNIX` block, mandatory deny paths incl. `.git/config` and `.git/hooks/`, Linux proxy-bypass limitation

**Kernel / systemd / distro primitives**
- <https://docs.kernel.org/userspace-api/landlock.html> — ABI table (v4 = TCP, v10 = UDP); unmediated syscalls; no `mount(2)`/`pivot_root(2)`
- <https://github.com/containers/bubblewrap> — "not a complete, ready-made sandbox"; namespace list; setuid mode removed
- <https://github.com/systemd/systemd/blob/main/man/systemd-nspawn.xml> — unprivileged-operation limitations
- <https://github.com/systemd/systemd/blob/main/man/machinectl.xml> — `machinectl shell`
- <https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/administration/containers.chapter.md> — "not perfectly isolated from the host system"
- <https://github.com/podman-container-tools/podman/blob/main/rootless.md> — rootless shortcomings

**VM / microVM options**
- <https://gvisor.dev/docs/architecture_guide/performance/> — VFS implementation costs, gofer boundary costs
- <https://github.com/firecracker-microvm/firecracker/blob/main/FAQ.md> — "< 125 ms startup"; "only 6 emulated devices"; `docs/design.md` device list; code search for `virtio-fs` → 0 hits
- <https://github.com/cloud-hypervisor/cloud-hypervisor>
- <https://github.com/microvm-nix/microvm.nix> (MIT) — `doc/src/intro.md`, `doc/src/host.md`, and <https://microvm-nix.github.io/microvm.nix/shares.html>
- <https://github.com/superradcompany/microsandbox> (Apache-2.0) — libkrun, OCI images, "under 100 milliseconds"
- <https://github.com/earendil-works/gondolin> (Apache-2.0) — README; <https://earendil-works.github.io/gondolin/architecture/>; <https://earendil-works.github.io/gondolin/limitations/>

**Local measurements (Tahani, 2026-08-11)**
- `uname -srm`; `/sys/kernel/security/lsm`; `/proc/sys/user/max_user_namespaces`; `/dev/kvm`;
  `cgroup.subtree_control` of the user session
- `hyperfine` runs for `sbx version`, `sbx exec`, `nono wrap`, `nono run`, `srt`, `bwrap`, `nsenter`
- `bwrap` + `nsenter --preserve-credentials --user --mount --pid --uts --ipc` attach experiment
- `nix eval nixpkgs#{nono,sandbox-runtime,bubblewrap}.version` → 0.71.0 / 0.0.71 / 0.11.2
