# microvm.nix vs bubblewrap+nsenter for the Herdr workspace sandbox

- Status: **decided by measurement.** Both designs were built and run on Tahani. The
  conditional tie in earlier revisions of this document no longer stands — see §0.1 and §15.
- Date: 2026-08-11
- Scope: `modules/features/ai/herdr-sandbox.nix`, `modules/features/ai/_herdr-sandbox/**`,
  ADR [0001](../adr/0001-docker-sandboxes-herdr-workspaces.md),
  [herdr-sandbox-alternatives.md](./herdr-sandbox-alternatives.md)
- Host: Tahani — Linux 6.18.41 x86_64, NixOS, `/dev/kvm` present, bubblewrap 0.11.2,
  systemd user session with `cpu io memory pids` reachable at `user@1000.service`
- Requirement labels **R1–R13** are defined in
  [herdr-sandbox-alternatives.md §1](./herdr-sandbox-alternatives.md#1-what-the-current-system-actually-guarantees)
  and reused here unchanged.

All sources accessed **2026-08-11**. Evidence labels as in the previous report: **measured**
(run here, command given), **documented** (project that owns the code), **inferred** (marked
as deduction), **unknown** (flagged, never guessed).

### Primary measurement records

Both designs were prototyped and measured. These two trees are the authoritative record for
every number in this document that is labelled *measured*; this report summarises them and does
not restate their raw logs.

| Record | Covers |
| --- | --- |
| `/var/tmp/herdr-microvm-spike/results.md` (+ `logs/`) | Design A: shared runner build, 4 concurrent VMs at `cid=3`, cold/warm timings, PTY fidelity, cross-pane control, `/nix` read-only, metadata performance with and without share tuning, blockers |
| `/tmp/herdr-bwrap-spike/` (`cold-ms.txt`, `holder.sh`, `pane-*.log`, `nvim.log`, relay + proxy logs) | Design B: transient-service holder, cold prompt-ready, warm attach, PTY allocation via inner `script`, slice-based cgroup limits, two-legged egress relay, Herdr `agent.start` result |

---

## 0. What this pass changes versus the previous report

### 0.1 The decisive result

**Design B fails a mandatory gate.** With a Herdr pane root `exec`ing the wrapper, `herdr agent
start` rejected **both** bwrap pane variants — direct `nsenter`/Fish and the PTY-correct inner
`script` form — as `not an available shell`, including with a Nix-store binary copy named
`fish`. R12 is not optional, so design B is **failed, not merely behind**, while PID namespaces
are retained.

**Design A passes it.** A Herdr pane root `exec`ed a Nix-store copy of `ssh` named `fish`,
attached over `vsock-mux`, got a real guest Fish prompt, and `herdr agent start` **accepted the
pane as an available shell and launched Pi inside the guest**. Readiness detection then timed
out — the throwaway guest deliberately lacked the Herdr guest relay and the agent-state
extension. That is a broker/relay integration gate, **not** a shell or PTY rejection.

So the recommendation is no longer conditional on how one weights the guest-kernel boundary.
Design A wins on a hard functional gate *and* keeps R11.

### 0.2 Corrections

Positions from earlier revisions that the source review or the spikes overturned.

| Previous position | Established here |
| --- | --- |
| `nsenter --join-cgroup` recommended so pane processes fall under the workspace's limits (called "the single most important flag the earlier prototype was missing") | **Wrong and not viable.** *Measured*: joining a sibling cgroup from a pane fails `write cgroup.procs failed: Permission denied` even with `Delegate=yes` and user-owned cgroups. The working design is a **workspace `.slice`** carrying the limits, with the holder service and each pane scope underneath it; `nsenter --cgroup` joins the namespace *view* only. §5.1, §8 |
| Design B's PTY gap treated as an open question with three candidate fixes | **Resolved, and it needs a fix in the pane path**: direct `nsenter` inherits the host PTY and `ttyname()` fails; wrapping the guest command in `script` allocates a sandbox devpts correctly. *Measured*: 3 simultaneous PTYs at `/dev/pts/0,1,2`, `/dev/tty` readable, Nvim full-screen exit 0, cross-pane visibility and kill pass. §5.4 |
| R12 (Herdr `agent.start`) assumed satisfiable in both designs by a `fish`-named exec path | **False for design B.** *Measured*: rejected as `not an available shell` in both pane variants. True for design A. §0.1, §5.5 |
| Latency framed as design B's decisive advantage | Still true directionally but much smaller than the earlier no-op figures implied once real prompts are measured: **131.1 ms** warm to an interactive Fish prompt for B vs **~340 ms** for A. §10.1 |
| "`systemd-run --user --scope`" as the limit/holder primitive | **Wrong primitive.** A scope cannot be the persistent holder: it does not fork, it is synchronous, and its processes stay children of the caller. A transient **service** is required. §3.2 |
| The prototype used `--die-with-parent` | **Incompatible with persistence** — it is `PR_SET_PDEATHSIG`, so the sandbox dies with the pane that created it. §3.2 |
| "hand the sandbox a Unix socket to `nono proxy`" | `nono proxy` is **TCP-only** (`--listen`/`--port`); with `--unshare-net` it is unreachable without a **two-legged relay**. The AF_UNIX leg itself does work — now measured. §6 |
| Resource limits "no I/O cap in the user session" was left open | **I/O limits do work**: systemd enables the `io` controller on demand; `io.max` was written for a transient user unit. `cpuset` is the one that is genuinely unavailable. §8 |
| microvm.nix treated as "declarative guests, dynamic lifecycle not native"; a first draft of §4.3 stated that one prebuilt runner **cannot** instantiate N workspaces | **Withdrawn — that was wrong.** `lib/runner.nix` execs `microvmConfig.extraArgsScript` at start time and appends its stdout to the hypervisor argv, and share sources, virtiofs sockets, the control socket, volume images and cloud-hypervisor's vsock socket are all **relative** strings resolved against the unit's `WorkingDirectory=${stateDir}/%i`. One shared runner in N state directories works *through the stock host units*. §4.3 |
| "each workspace necessarily costs a Nix eval **and** a root-owned unit" (§2.1) | **Half wrong.** The Nix evaluation is a property of the stock `microvm -c` lifecycle only, not of the architecture. The root-owned unit and `/var/lib/microvms` **do** remain, unless you leave the stock host module behind entirely (T3). §2.3, §4.3.4 |
| "QEMU for the prototype" | **Reversed to cloud-hypervisor**, on the vsock asymmetry: QEMU's `vhost-vsock` CID is host-global, cloud-hypervisor's is per-VMM behind a relative AF_UNIX mux path — which is exactly what a shared runner needs. §4.5 |

Two facts that were previously "inferred" are now measured: a second pane really does join a
live sandbox and share its process namespace (§5.3), and a sandboxed child really cannot
`setns` back to host namespaces (§9.2).

### 0.3 Claims promoted from documented/unknown to measured

- **T2 shared runner works.** 4 concurrent VMs from prebuilt runners, all configured `cid=3`,
  each with a relative `notify.vsock` in its own directory, distinct `boot_id`s, correct
  per-instance state, all independently reachable, all unprivileged. §4.3.5
- **cloud-hypervisor's CID is not host-global.** `CONFIG_VHOST_VSOCK=m`, module never loaded,
  zero processes holding `/dev/vhost-vsock` — the doc ambiguity flagged earlier is resolved in
  favour of CH. §4.5
- **virtiofs `/nix` performance is acceptable with tuning**, and the tuning matters: `cache=always`
  plus `posixAcl=false` buys 2–3×. §7.1
- **Design B's egress relay works end to end**: allowlisted host 200, denied host 403, and no
  path out with the proxy env unset. §6.1
- **Design B's limits bind panes** via the slice design: a 700 MiB pane under `MemoryMax=256M`
  with `MemorySwapMax=0` was OOM-killed while the holder stayed active. §8

---

## 1. The two architectures in one paragraph each

**(A) microvm.nix.** Each workspace is a NixOS guest running under a hypervisor (QEMU or
cloud-hypervisor) started by the **system** service manager as `microvm@<name>.service`,
with per-VM state in `/var/lib/microvms/<name>/`. The host `/nix/store` is passed in
read-only over virtiofs; the private clone lives on a block volume or a writable share.
Panes attach as SSH sessions over AF_VSOCK. Keeps R11 (guest kernel boundary). Costs a Nix
evaluation and a root-owned system unit per workspace.

**(B) bubblewrap + nsenter + transient units.** Each workspace is one long-lived `bwrap`
process tree held by a **transient user service** `herdr-ws-<id>.service`, owning private
mount/PID/UTS/IPC/user/net/cgroup namespaces, with limits applied by the unit's cgroup. Panes
attach with `nsenter` into the holder's namespaces. Entirely inside the user session, no root,
sub-millisecond attach. Gives up R11 (shared kernel) and the Ubuntu/`apt` guest (R9).

---

## 2. Per-workspace and per-pane lifecycle, side by side

### 2.1 Design A

Two variants, and the difference between them is the subject of §4.3. **T1** is the stock
imperative lifecycle; **T2** shares one prebuilt runner across all workspaces and is the variant
this report now recommends.

```
# T1 — stock lifecycle: one Nix evaluation per workspace
nix build .#nixosConfigurations."ws-<id>".config.microvm.declaredRunner
  → /var/lib/microvms/ws-<id>/current            (symlink, root-owned)
  → /nix/var/nix/gcroots/microvm/ws-<id>         (GC root, root-owned)

# T2 — shared runner: ONE build for all workspaces, provisioning is a symlink
nix build .#…declaredRunner                      (once, not per workspace)
  → /nix/var/nix/gcroots/herdr-microvm-runner    (one GC root for all workspaces)
mkdir -p /var/lib/microvms/ws-<id>
ln -sT <shared-runner> /var/lib/microvms/ws-<id>/current
  (relative share sources / sockets / volume images resolve per directory; `booted` is
   created by microvm-set-booted@; volumes are mkfs'd on first start by microvm-run)

# both variants then use the SAME stock host units
systemctl start microvm@ws-<id>.service          (system manager, root)
  ├── microvm-virtiofsd@ws-<id>.service          (Type=notify, Restart=always, runs as ROOT)
  ├── microvm-set-booted@ws-<id>.service         (oneshot: ln -s $(readlink current) booted)
  └── ExecStart=/var/lib/microvms/ws-<id>/current/bin/microvm-run
        WorkingDirectory=/var/lib/microvms/ws-<id>   ← what makes T2 work
        User=microvm  Group=kvm  Restart=always  RestartSec=5s
        → cloud-hypervisor → guest kernel → guest systemd → sshd-vsock.socket

pane:  fish-named wrapper → ssh vsock-mux/var/lib/microvms/ws-<id>/notify.vsock
```

(`microvm-tap-interfaces@`/`microvm-macvtap-interfaces@`/`microvm-pci-devices@` are also in the
`requires` chain but are no-ops here: the recommended shape declares no `microvm.interfaces` and
no devices, which is also what makes one runner reusable — see §4.3.3.)

Sources: `microvm@` unit body, `ExecStart`, `Restart=always`, `User`/`Group`, and the
`requires`/`after` chain in
[`nixos-modules/host/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/host/default.nix);
`user = "microvm"; group = "kvm"` at the top of the same file; `stateDir` default
`/var/lib/microvms` in
[`nixos-modules/host/options.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/host/options.nix);
`microvm-virtiofsd@` has **no `User=`**, so it runs as root
(same file, `serviceConfig` = `WorkingDirectory`, `ExecStart`, `LimitNOFILE`, `NotifyAccess`,
`PrivateTmp`, `Restart`, `RestartSec`, `SyslogIdentifier`, `Type=notify`, `KillMode=mixed`).
The `nix build`, the two GC-root symlinks and the `ssh` exec are in
[`pkgs/microvm-command.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/pkgs/microvm-command.nix).

### 2.2 Design B

```
systemd-run --user --unit=herdr-ws-<id> --property=Type=exec \
  --property=MemoryMax=8G --property=TasksMax=… --property=CPUQuota=400% \
  --property=KillMode=control-group --property=Restart=no \
  -- bwrap <mount/ns/hardening args> -- <holder command>          # per workspace

  holder pid = bwrap, PPID = systemd --user            (measured)
  cgroup      = user@1000.service/app.slice/herdr-ws-<id>.service

pane:  fish-named wrapper → nsenter -t <inner-pid> --preserve-credentials \
                              --user --mount --pid --uts --ipc --net --cgroup -- fish -l
```

*Measured on Tahani, 2026-08-11* — the unit ran with `ActiveState=active`,
`ControlGroup=/user.slice/user-1000.slice/user@1000.service/app.slice/herdr-exp-ws.service`,
`MemoryMax=2147483648`, `TasksMax=512`, `CPUQuotaPerSecUSec=2s`, and the holder's parent was
pid 764169 = `systemd` (the user manager), not the invoking shell.

### 2.3 The structural difference that matters

Under **T1**, design A has two lifecycles per workspace — a build-time one (Nix evaluation
producing a runner) and a run-time one (the system unit). Under **T2** the build-time lifecycle
collapses to once-per-configuration, shared by all workspaces, and per-workspace provisioning is
a directory plus a symlink.

What survives in both variants, and is the real structural difference from design B, is
**privilege**: `/var/lib/microvms` and the `microvm@`/`microvm-virtiofsd@` template units are
root-owned, so creating a workspace requires a privileged step. Design B's workspace is created
by the same unprivileged user that opens the pane, in that user's own service manager. That —
not the Nix evaluation — is the axis the two designs genuinely differ on. (T3 in §4.3.4 removes
even that, at the cost of the stock host module.)

---

## 3. Is `systemd-run --user --scope` the right holder? No.

### 3.1 What the documentation says

From [systemd-run(1)](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html)
(read from the locally installed page, systemd as shipped on Tahani):

> "If a command is run as transient service unit, it will be started and managed by the
> service manager like any other service … It will run in a **clean and detached execution
> environment, with the service manager as its parent process**. In this mode, systemd-run
> will start the service **asynchronously** in the background and return after the command has
> begun execution"

> "If a command is run as transient scope unit, it will be executed by systemd-run **itself as
> parent process** and will thus **inherit the execution environment of the caller**. …
> Execution in this case is **synchronous**, and will return only when the command finishes."

From [systemd.scope(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.scope.html):

> "Unlike service units, scope units manage **externally created processes, and do not fork off
> processes on its own**."

> "unlike service units, scope units have no 'main' process: all processes in the scope are
> equivalent. The lifecycle of the scope unit is thus not bound to the lifetime of one specific
> process, but to the existence of **at least one process** in the scope. … Since processes
> managed as scope units generally **remain children of the original process that forked them
> off**, it is also the job of that process to collect their exit statuses and act on them as
> needed."

### 3.2 Why that disqualifies `--scope`, point by point

| Property | `--scope` | transient service |
| --- | --- | --- |
| **Ownership** | Holder stays a child of the pane's shell; systemd only accounts for it | Holder's parent is `systemd --user` (*measured*) |
| **Blocking** | Synchronous — the pane shell blocks until the holder exits, so the pane *is* the holder's lifetime | Asynchronous — `systemd-run` returns once the command has started |
| **Pane exit** | Holder is reparented; with `--die-with-parent` it is **SIGKILLed** | Unaffected: the pane was never its parent |
| **Restart** | No `Restart=` semantics (no main process to restart) | `Restart=`, `RestartSec=`, `ExecStopPost=` all available |
| **Cleanup** | Ends when the *last* process exits — a stray orphan keeps the unit (and its namespaces) alive | `systemctl --user stop` + `KillMode=control-group` kills the whole cgroup deterministically |
| **Escape** | Any process that leaves the cgroup leaves the limits | Same cgroup caveat, but `Delegate=` + a known unit name make it auditable |
| **Start failure** | Reported inline | `Type=simple` reports success "as soon as the `fork()` … succeeded … even if the specified command cannot be started"; **`Type=exec` is required** for a fail-closed R10 |

`--die-with-parent` compounds the first mistake: bwrap(1) documents it as
"Ensures child process (COMMAND) dies when bwrap's parent dies. Kills (SIGKILL) all bwrap
sandbox processes in sequence from parent to child … See prctl, `PR_SET_PDEATHSIG`."
([bwrap(1)](https://github.com/containers/bubblewrap/blob/main/bwrap.xml)). For an
*ephemeral* sandbox that is the correct safety default. For a workspace holder that must
outlive the pane that created it, it is exactly wrong. The earlier prototype in
`herdr-sandbox-alternatives.md §4.3` used it, and that prototype therefore only demonstrated
the attach mechanism, not a viable holder.

**Conclusion:** the holder must be a transient (or templated) **service** —
`systemd-run --user --unit=herdr-ws-<id> --property=Type=exec … -- bwrap …` **without**
`--die-with-parent`. A `.scope` remains appropriate for one thing: if you ever want to
account for a *pane* separately, the pane's `nsenter` can be put in its own scope under the
workspace slice.

A design note that follows: a templated unit (`herdr-ws@.service`, generated by Home Manager)
is preferable to `systemd-run` in the long run, because the holder's argument list — the whole
security policy of design B — then lives in a reviewed Nix file rather than in a command line
assembled by a Fish script. `systemd-run` is the right prototype vehicle; `herdr-ws@.service`
is the right destination.

---

## 4. microvm.nix, established from source

### 4.1 Supported hypervisors

`lib/default.nix` defines exactly eight, and `hypervisorsWithNetwork = hypervisors`:

```nix
hypervisors = [ "qemu" "cloud-hypervisor" "firecracker" "crosvm"
                "kvmtool" "stratovirt" "alioth" "vfkit" ];
```

([`lib/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/default.nix))
Each has a runner at `lib/runners/<name>.nix`.

### 4.2 Shares, `/nix/store`, and volumes

`microvm.shares` is a list of submodules with `tag`, `socket`, `source`, `securityModel`,
`mountPoint`, **`proto` (`enum [ "9p" "virtiofs" ]`, default `9p`)**, **`readOnly` (bool,
default false)**, `cache` (`auto|always|metadata|never`), `posixAcl`, `extraArgs`
([`nixos-modules/microvm/options.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/options.nix)).
So R4 is directly expressible: `readOnly = true` shares for `/nix/store` and for each of the
four caches, with a per-share virtiofsd `cache` policy.

Sharing the host store is a first-class mode, not a hack — `storeOnDisk` is *defined* in terms
of it:

```nix
storeOnDisk = mkOption {
  default = ! lib.any ({ source, ... }: source == "/nix/store") config.microvm.shares;
  description = "Whether to boot with the storeDisk, that is, unless the host's /nix/store is a microvm.share.";
};
```

That is the R4-preserving configuration and it removes the per-workspace store image entirely.
Two caveats from the same file: `registerClosure` ("Register system closure's store paths in
Nix db") is noted as possibly "incompatible with a persistent writable store overlay"; and
`storeDiskType` (`squashfs`/`erofs`) only matters in the *other* mode.

`microvm.volumes` submodules have `image`, `size` (MiB), `autoCreate` (default true,
"Created image on host automatically before start?"), `readOnly`, `label`, `mountPoint`,
`direct` (`O_DIRECT`), `fsType`, `mkfsExtraArgs` — enough for a private-clone block device
created on first boot without any host-side image tooling.

`asserts.nix` enforces two things worth knowing up front: every virtiofs share needs a unique
`socket` path, and `posixAcl = true` is **mutually exclusive** with virtiofsd
`--translate-uid`/`--translate-gid`
([`nixos-modules/microvm/asserts.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/asserts.nix)).
The second one is the uid-mapping fork in the road for R3 (§7.2).

### 4.3 Dynamic vs declarative lifecycle, and the N-workspaces question

**A previous draft of this report concluded that one prebuilt runner cannot instantiate N
workspaces. That conclusion was wrong, and this section replaces it.** The error was
methodological: I grepped `lib/runner.nix` for `getEnv` and `$MICROVM`, found nothing, and
inferred there was no runtime hook. There is one, it is a first-class option, and combined with
microvm.nix's relative-path conventions it makes a shared-runner design viable.

#### 4.3.1 The runtime hook

`microvm-run` — the script the host unit execs — ends like this
([`lib/runner.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/runner.nix)):

```bash
${preStart}
${createVolumesScript microvmConfig.volumes}
runtime_args=${lib.optionalString (microvmConfig.extraArgsScript != null) ''
  $(${microvmConfig.extraArgsScript})
''}

exec ${execArg} ${command} ${runtime_args:-}
```

and the option is documented as exactly that
([`nixos-modules/microvm/options.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/options.nix)):

> `extraArgsScript` … "A script to provide additional arguments for the hypervisor at runtime.
> The script must output a single line with arguments for the hypervisor."

The script's path is baked, but the script *runs at start time*, in the unit's working
directory, and can read the environment, the cwd and files in the state directory. Its stdout
is appended to the hypervisor's argv. That is a genuine per-instance parameterisation channel.

#### 4.3.2 Relative paths resolve per instance directory

microvm.nix's conventions already point this way, and the handbook says so outright
([shares.md](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/shares.md)):

> ```nix
> microvm.shares = [ {
>   proto = "virtiofs";
>   tag = "home";
>   # Source path can be absolute or relative
>   # to /var/lib/microvms/$hostName
>   source = "home";
>   mountPoint = "/home";
> } ];
> ```

Every other per-instance path defaults to a **relative** string:

| Value | Default / type | Resolves against |
| --- | --- | --- |
| share `source` | `nonEmptyStr`, documented as absolute *or relative* | cwd |
| virtiofs `socket` | `"${hostName}-virtiofs-${tag}.sock"` | cwd |
| control socket | `"${hostName}.sock"` | cwd |
| volume `image` | `types.str`; handbook example is `"nix-store-overlay.img"` | cwd |
| cloud-hypervisor vsock socket | `"notify.vsock"` | cwd |

And the cwd is per instance, in every unit of the chain: `microvm@%i`,
`microvm-virtiofsd@%i` and `microvm-set-booted@%i` all set
`WorkingDirectory = "${stateDir}/%i"`
([`nixos-modules/host/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/host/default.nix)).

Three further pieces make manual provisioning of an *identical* runner work end to end:

- **virtiofsd inherits the same relative resolution.** The generated `virtiofsd-run` passes the
  strings through verbatim — `--socket-path=<socket> … --shared-dir=<source>` under supervisord
  ([`nixos-modules/microvm/virtiofsd/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/virtiofsd/default.nix))
  — so a relative `source = "clone"` becomes `/var/lib/microvms/ws-A/clone` in one instance and
  `…/ws-B/clone` in another, from one runner.
- **Volumes are created per instance at start.** `createVolumesScript` runs inside
  `microvm-run` (hence in the cwd) and `mkfs`es the relative `image` if `autoCreate`
  ([`lib/volumes.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/volumes.nix)).
  Each state directory gets its own `home.img`.
- **Only `current` must be provisioned.** `microvm-set-booted@%i` does
  `rm -f booted; ln -s $(readlink current) booted`, so the stock unit chain derives `booted`
  itself. A state directory containing one symlink is enough to start.

#### 4.3.3 What genuinely differs per instance, and how each is handled

| Value | Baked? | Shared-runner handling |
| --- | --- | --- |
| share sources, sockets, volume images, control socket | relative | **resolve per cwd — nothing to do** |
| absolute read-only shares (`/nix/store`, the four caches) | absolute | identical across workspaces *by design* |
| guest hostname | baked, identical | cosmetic; Herdr names workspaces host-side |
| machined UUID / registration | derived from hostname | **`registerWithMachined` defaults to `false`** — no collision unless you opt in |
| tap interface names + MACs | baked, and written to `share/microvm/tap-interfaces` | **avoid entirely**: use no `microvm.interfaces` and do egress over vsock (§6.2 already recommends this) |
| vsock | baked when `vsock.cid != null` | see below — the one real obstacle, and it is hypervisor-specific |

The vsock case is where QEMU and cloud-hypervisor part company, and it decides §4.5.

- **QEMU uses the host kernel's vhost-vsock.** The runner emits
  `lib.optionals (vsock.cid != null) [ "-device" "vhost-vsock-${devType},guest-cid=${toString vsock.cid}" ]`
  ([`lib/runners/qemu.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/runners/qemu.nix)).
  `vhost-vsock` registers the guest CID with the host kernel, so CIDs are **host-global** and
  two VMs cannot share one. An identical runner would therefore need the CID injected at
  runtime — which `extraArgsScript` can do, since with `vsock.cid = null` the runner emits **no
  vsock device at all**, leaving no static argument to conflict with. Workable, but it
  reintroduces a host-wide CID allocator.
- **cloud-hypervisor does not use host AF_VSOCK for host↔guest at all.** From
  [systemd-ssh-proxy(1)](https://github.com/systemd/systemd/blob/main/man/systemd-ssh-proxy.xml):
  > "`vsock-mux/` followed by an absolute AF_UNIX file system path to a socket is similar but for
  > **cloud-hypervisor/firecracker which do not allow direct AF_VSOCK communication between the
  > host and guests, and provide their own multiplexer over AF_UNIX sockets**."

  and cloud-hypervisor's own documentation shows the host side as a Unix socket carrying a text
  handshake — `echo -e "CONNECT 1234\nHello from host!" | socat - UNIX-CONNECT:/tmp/ch.vsock`
  ([`docs/vsock.md`](https://github.com/cloud-hypervisor/cloud-hypervisor/blob/main/docs/vsock.md)).
  The CID is therefore meaningful **within one VMM's multiplexer**, and the host-facing
  identifier is the socket path — which defaults to the relative `notify.vsock`. So N instances
  of one runner can each carry `cid=3` with per-directory sockets, and no allocator is needed.
  Caveat to test rather than trust: CH's doc still lists `CONFIG_VHOST_VSOCK` under "Kernel
  Requirements", which reads like inherited boilerplate from the Firecracker implementation it
  says it is "based on" — so **CID reuse across concurrent CH VMs is documented-plausible, not
  proven, and is hard gate **H1** (§13)**.

`extraArgsScript` and the statically generated argv do not conflict for either hypervisor,
because both omit the vsock flag entirely when no CID is configured — CH's is
`lib.optionals (vsockOpts != "") ["--vsock" vsockOpts]`
([`lib/runners/cloud-hypervisor.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/runners/cloud-hypervisor.nix)).
Note the consequence: CH sets `supportsNotifySocket = vsockCID != null`, so a runtime-injected
CID means the host module must run with `microvm.host.useNotifySockets = false` (the unit then
uses `Type = "simple"` rather than `"notify"`). One further guard, from the same file: CH
`throw`s if `microvm.vsock.cid` and a `--vsock` in `microvm.cloud-hypervisor.extraArgs` are both
set — that check is on the *static* `extraArgs`, not on `extraArgsScript`, so it does not
obstruct the runtime path.

#### 4.3.4 Three distinct lifecycles — pick deliberately

| | **T1 — stock `microvm` command** | **T2 — stock host module, manual provisioning** | **T3 — fully custom runner** |
| --- | --- | --- | --- |
| Per-workspace Nix eval | **yes** (`nix build …nixosConfigurations.<name>…declaredRunner`) | **no** — one shared runner, N state dirs each with a `current` symlink | **no** |
| Host units | stock `microvm@`, `microvm-virtiofsd@`, `microvm-set-booted@` | **the same stock units, unmodified** | yours |
| Privilege | root: `/var/lib/microvms`, system units, `/nix/var/nix/gcroots/microvm/*` | root: same | **potentially none** — `/dev/kvm` is `crw-rw-rw-` on Tahani (*measured*), so a user unit can exec `microvm-run` with a user-owned `WorkingDirectory` |
| GC roots | `microvm -c` creates them | one root for the shared runner (not one per workspace) | one root for the shared runner |
| Upgrade | `microvm -u` | re-point every `current` symlink; restart | your own |
| Former unknowns, now measured | build cost **28.4 s** for one runner (§4.3.5) | **CID reuse works** — 4 concurrent VMs at `cid=3` (§4.3.5) | **blocked**: `virtiofsd-run` refuses to run unprivileged (§4.3.6) |
| Support status | fully supported | **supported components, unsupported composition** — nothing in the source forbids it, but `microvm -c`/`-u` will not manage it; **demonstrated working** (§4.3.5) | outside microvm.nix's remit |

**Corrected answer to the question as posed: yes, with a caveat.** One prebuilt runner can
instantiate N per-workspace VMs, using relative share sources/sockets/volume images plus
`extraArgsScript` for anything genuinely dynamic, and it does so *through the stock host
module* (T2) rather than requiring a custom control plane. The caveat is the vsock CID: with
cloud-hypervisor the per-instance Unix mux path makes it a non-issue; with QEMU the host-global
CID must be injected at runtime and allocated by you.

That said, T2 buys away the *Nix evaluation*, not the *root*. `/var/lib/microvms` and the
system template units remain root-owned, so workspace creation still needs a privileged step
that today's dispatcher does not have. T3 is the only tier that removes that too, and it trades
away the stock host module to get there.

This also clarifies the microvm.nix-capability-vs-hypervisor-capability line the brief asked
for, in the opposite direction from my earlier claim: microvm.nix *does* expose a runtime
argument channel (`extraArgsScript`) and *does* resolve per-instance paths relative to the
working directory. What it does not expose is a first-class "instantiate this template N times"
command — `microvm -c` is name-per-configuration. The gap is in the tooling, not in the
generated runner.

#### 4.3.5 T2 built and run — measured

*Measured, Tahani 2026-08-11* (record: `/var/tmp/herdr-microvm-spike/results.md` §0–§1). One
`nix build` of `…config.microvm.declaredRunner` took **28.4 s** (a tuned second variant, 6.5 s),
and the generated `microvm-run` carries only relative per-instance paths:

```
--vsock 'cid=3,socket=notify.vsock'
--fs 'socket=spike-virtiofs-ro-store.sock,tag=ro-store' 'socket=spike-virtiofs-state.sock,tag=state'
--api-socket spike.sock
```

Four concurrent VMs were then started from prebuilt runners — three from one runner, one from
the tuned runner — each by symlinking `current` into its own state directory and running with
that directory as cwd:

| instance | runner | cid | cwd | boot_id | state marker |
| --- | --- | --- | --- | --- | --- |
| ws-a | yhh4bhxvk4lh… | 3 | inst/ws-a | 05a049 | marker-for-ws-a |
| ws-b | yhh4bhxvk4lh… | 3 | inst/ws-b | 1bff64 | marker-for-ws-b |
| ws-c | yhh4bhxvk4lh… | 3 | inst/ws-c | 7f37a5 | marker-for-ws-c |
| ws-tuned | 44hymvzmwp3x… | 3 | inst/ws-tuned | d8c0ef | marker-for-ws-tuned |

All four independently reachable, all `vsock_arg=cid=3,socket=notify.vsock`, distinct boot ids,
each seeing only its own writable share. **No `extraArgsScript` was needed at all** — the
relative-path mechanism alone was sufficient with cloud-hypervisor.

The spike ran **entirely unprivileged**: no `sudo`, no host configuration, and
`/var/lib/microvms` was never created. It therefore also exercised something close to T3, with
one blocker (§4.3.6).

#### 4.3.6 The one T2-irrelevant, T3-fatal blocker

*Measured*: the generated `virtiofsd-run` cannot run unprivileged.

```
Error: Can't drop privilege as nonroot user
```

because the generated supervisord config hardcodes the user:

```ini
[supervisord]
nodaemon=true
user=root
```

The spike worked around it by launching the two per-share virtiofsd scripts directly — they
already handle non-root (`if [ $(id -u) = 0 ]` around `--rlimit-nofile`) and take the relative
`--socket-path`/`--shared-dir`. **T2 is unaffected** (the stock `microvm-virtiofsd@%i.service`
runs as root). **T3 requires bypassing this wrapper.**

A related benign warning appeared on both shares and may contribute to the metadata cost in
§7.1, untested against a root-run virtiofsd:

```
WARN virtiofsd::passthrough] File handles do not appear safe to use, disabling file handles altogether
```

### 4.4 Multi-PTY attachment

`microvm.vsock.ssh.enable` documents the intended path verbatim:

> "SSH server listening on VSOCK for host-to-guest connections. When enabled, the guest's SSH
> server will listen on the VSOCK interface, allowing the host to connect without network
> configuration. Requires `microvm.vsock.cid` to be set. From the host, connect using:
> - For qemu/crosvm/kvmtool: `ssh vsock/<CID>`
> - For cloud-hypervisor: `ssh vsock-mux/<path-to-notify.vsock>`
> - Or use: `microvm -s <vmname>`"

and the implementation is deliberately thin — "systemd's ssh-generator automatically creates
`sshd-vsock.socket` when it detects VSOCK is available"
([`nixos-modules/microvm/vsock-ssh.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/vsock-ssh.nix)).

So: N panes = N socket-activated SSH sessions into one guest. Each is a genuine guest-side PTY
allocated by the guest's own `sshd` in the guest's own `devpts`, and all of them share the
guest's PID namespace. **This is a cleaner R2 than design B's** (§5.4) — it is the same shape
as `sbx exec -it` today. Costs: an sshd in every guest, and a host-side key/`known_hosts`
policy (`microvm -s` uses `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`, which
is fine for vsock but is a decision to make explicitly).

*Measured* — this worked exactly as documented, with **no PTY workaround needed**:

```
tty            -> /dev/pts/0
/dev/tty       -> character device, readable
TERM           -> xterm-256color (propagated)
3 simultaneous PTYs -> /dev/pts/0, /dev/pts/1, /dev/pts/2, all present in `who`
nvim over vsock -> alternate screen entered, edit made, :wq wrote through, clean exit
```

`stty size` reported `0 0` because the test harness supplied no window size; a real terminal
does. Cross-pane control also passed: a job started in one session was listed by a second and
killed by a third, and the guest saw **0** host `cloud-hypervisor` processes.

Whether a CID allocator is also needed depends on the hypervisor, per §4.3.3: with QEMU the CID
is host-global and you must allocate it; with cloud-hypervisor the host-facing identifier is the
per-instance mux socket path, so the same in-guest CID can repeat across workspaces. Note for
the attach command either way: systemd-ssh-proxy(1) requires "`vsock-mux/` followed by an
**absolute** AF_UNIX file system path", so the pane wrapper attaches to
`ssh vsock-mux/var/lib/microvms/ws-<id>/notify.vsock` even though the runner's own copy of that
string is relative.

Serial console is the fallback, not the mechanism: it is single-consumer, and `microvm -r`
occupies it in the foreground.

### 4.5 QEMU or cloud-hypervisor?

| | QEMU | cloud-hypervisor |
| --- | --- | --- |
| 9p shares | yes | not offered — the runner `throw`s: "cloud-hypervisor supports only shares that are virtiofs" |
| virtiofs | yes | yes; runner sets up shared memory because "Shared memory is required for usage with virtiofsd" |
| Control socket | QMP: `-qmp unix:${socket},server,nowait`; shutdown is a QMP `system_powerdown` written with `socat` | `--api-socket ${socket}`, relative by default; shutdown via `ch-remote --unix-socket ${socket}`; `preStart` does `rm -f '${socket}'` to clear a stale one |
| **vsock identity** | host-kernel `vhost-vsock-pci,guest-cid=N` → **CID is host-global**; `ssh vsock/<CID>` | AF_UNIX multiplexer, `cid=N,socket=notify.vsock` (**relative**) → **CID is per-VMM**; `ssh vsock-mux/<abs path>` |
| Shared-runner fit (§4.3) | needs a host-wide CID allocator, injected via `extraArgsScript` | **works as-is**: identical CID, per-directory socket |
| systemd notify | via vsock | `supportsNotifySocket = vsockCID != null`; runner starts a `socat` to forward the notify socket over vsock |
| Attack surface | large, C, general-purpose | smaller, Rust, purpose-built |

**Recommendation, reversed from the previous draft: cloud-hypervisor.** The earlier draft chose
QEMU to "keep the experiments free of a third variable", but that reasoning assumed a
per-workspace build where the CID was baked anyway. Once the shared-runner model (§4.3) is on
the table, the vsock addressing difference stops being cosmetic and becomes the deciding
property: cloud-hypervisor's per-instance Unix mux path means N workspaces run one identical
runner with no allocator and no runtime argument injection at all, while QEMU's host-global CID
forces a stateful allocator plus an `extraArgsScript` on the workspace-creation path. That
cloud-hypervisor's attack surface is smaller and its shares are virtiofs-only — which is what R4
wants anyway — makes the choice over-determined rather than marginal.

Two costs to accept with it: no QMP, so shutdown goes through `ch-remote` against the API
socket; and `supportsNotifySocket` depends on a statically configured CID, so if a CID is ever
injected at runtime the host module must run with `microvm.host.useNotifySockets = false`.
Neither touches the attach path.

**Gate H1 has now passed on the cloud-hypervisor side, and the doc ambiguity is resolved.**
*Measured*: four concurrent VMs shared `cid=3` with no interference (§4.3.5), and the host kernel
vsock stack was never involved —

```
CONFIG_VHOST_VSOCK=m        (module)
lsmod | grep -c vsock       -> 0     (never loaded)
processes holding /dev/vhost-vsock -> 0
```

The `CONFIG_VHOST_VSOCK` line under "Kernel Requirements" in cloud-hypervisor's own vsock doc is
therefore not a requirement for the host↔guest mux path, and CH CIDs are **not** host-global.
QEMU remains the documented fallback if a future kernel or CH version changes this, but it is no
longer on the critical path.

Firecracker is not a candidate here for the reason established in the previous report: no
shared-filesystem device, so R4 is unreachable.

---

## 5. Pane attach: exact mechanics

### 5.1 Design B: the `nsenter` invocation, and why each part is required

Verified against [nsenter(1)](https://github.com/util-linux/util-linux/blob/master/sys-utils/nsenter.1.adoc)
as installed, plus [setns(2)](https://man7.org/linux/man-pages/man2/setns.2.html) and
[user_namespaces(7)](https://man7.org/linux/man-pages/man7/user_namespaces.7.html) from
man-pages 6.18 (built locally from nixpkgs to read the upstream text).

```
nsenter --target <inner-pid> --preserve-credentials \
        --user --mount --pid --uts --ipc --net --cgroup \
        -- <fish-named wrapper> -l
```

- **`--preserve-credentials` is mandatory.** Without it, "The default is to drop supplementary
  groups and set GID and UID to 0" — and *measured*: `nsenter … --user --mount` without it
  fails with `nsenter: setgroups failed: Operation not permitted`. With it, the attached shell
  runs as uid 1000 inside (*measured*).
- **`--user` first, and it must be a descendant.** setns(2): "A process reassociating itself
  with a user namespace must have the `CAP_SYS_ADMIN` capability in the target user namespace.
  (This necessarily implies that it is only possible to join a descendant user namespace.)"
  The host user qualifies because of the ownership rule in user_namespaces(7): "When a user
  namespace is created, the kernel records the effective user ID of the creating process as
  being the 'owner' of the namespace. A process that resides in the parent of the user
  namespace and whose effective user ID matches the owner of the namespace has **all
  capabilities** in the namespace."
- **`--mount` needs the mount-namespace rule satisfied**: setns(2) requires "both
  `CAP_SYS_CHROOT` and `CAP_SYS_ADMIN` capabilities in its own user namespace and
  `CAP_SYS_ADMIN` in the user namespace that owns the target mount namespace" — which the
  preceding `--user` join grants ("Upon successfully joining a user namespace, a process is
  granted all capabilities in that namespace").
- **`--pid` implies a fork.** nsenter(1): "nsenter will fork by default if changing the PID
  namespace, so that the new program and its children share the same PID namespace and are
  visible to each other." Do **not** pass `--no-fork`. setns(2) also constrains the target:
  `CLONE_NEWPID` — "fd must refer to a **descendant** PID namespace."
- **`--net` should be joined.** The previous prototype omitted it. Joining it is what makes the
  pane's egress obey the same default-deny as the holder; a pane that stayed in the host netns
  would have unrestricted network while believing it was sandboxed. This is a correctness bug
  waiting to happen, not a nicety.
- **`--cgroup` joins the namespace *view*** so `/proc/self/cgroup` inside the pane reflects the
  workspace, matching what the holder sees. It does **not** move the pane into the holder's
  cgroup, and that is fine — see the correction below.
- **`--join-cgroup` must NOT be used. Correction to an earlier revision of this section,** which
  called it "the single most important flag the earlier prototype was missing". *Measured*: from
  a pane in a sibling cgroup it fails

  ```
  write cgroup.procs failed: Permission denied
  ```

  even with `Delegate=yes` and user-owned cgroups. The working design puts the limits one level
  up instead — a workspace `.slice` owning `MemoryMax`/`MemorySwapMax`/`TasksMax`/`CPUQuota`,
  with the holder service and each synchronous pane scope created underneath it (§8). Membership
  then comes from unit placement, not from `setns`-time cgroup migration.
- `--uts`/`--ipc` for a coherent hostname and IPC view.
- `--wdns=<checkout>` to land in the workspace directory *after* namespace entry (the spike used
  `--wdns=/workspace`); `--wd` would resolve in the caller's namespace instead.
- Not needed: `--time` (no use case), `--env` (Herdr passes its own environment).

One API constraint worth recording because it forecloses an obvious implementation: setns(2)
says "A **multithreaded** process may not change user namespace with `setns()`", and "a process
can't join a new user namespace if it is sharing filesystem-related attributes … with another
process". So the attach step cannot be done in-process by a Node or Go helper; it must be a
single-threaded `execve` of `nsenter` (or a tiny purpose-built C/Rust equivalent).

### 5.2 Design A: the SSH-over-vsock equivalent

`ssh vsock/<CID>` (QEMU) with the pane wrapper exec'ing a `fish`-named path. There is no
namespace juggling, no credential preservation question, no cgroup-escape footgun: the guest's
`sshd` allocates the PTY, and the guest kernel enforces everything.

### 5.3 R2 verified for design B

*Measured on Tahani, 2026-08-11.* Inside the holder, `/proc/1/comm` is `bwrap` (its pid-1
reaper) and the sandbox sees 5 processes. Attach #1 started `setsid sleep 500`; a **separate**
attach #2 then listed it (`pid 24`) in the sandbox's own `ps`. Cross-pane process visibility
and control are real. (An earlier run appeared to fail only because `ps -o comm` renders the
truncated exec path, not `sleep`, so the grep missed it — mechanism was fine, test was wrong.)

### 5.4 The `ttyname()` gap in design B — resolved, at the cost of a wrapper

*Measured*: with the holder built using bwrap's `--dev /dev` and `--new-session`, a pane attached
by plain `nsenter` **inherits the host PTY** and `tty(1)` reports `ttyname error: No such device`
— the fd works but the path does not resolve, because the PTY lives in the host's devpts while
the sandbox has its own instance.

**The fix that works is the third candidate**: allocate the PTY *inside* the namespace by
wrapping the guest command in `script`. *Measured* with that wrapper:

```
3 simultaneous PTYs -> /dev/pts/0, /dev/pts/1, /dev/pts/2
/dev/tty            -> readable
nvim full-screen    -> exited 0
cross-pane process visibility and kill -> pass
```

So design B can reach PTY parity, but only through an extra in-namespace PTY allocator on every
pane. Design A gets the same result natively from the guest's `sshd` (§4.4). Gate H3's PTY half
therefore passes for both; its `agent.start` half does not (§5.5).

### 5.5 R12 — Herdr's shell-process-name requirement: design B FAILS, design A passes

The mechanism is sound in both designs: *measured*, the kernel sets `comm` from the basename of
the exec'd path, so a symlink named `fish` pointing at `bash` yields `comm=fish`. (Incidental
trap: the target must not be argv[0]-dispatched — a `fish`-named symlink to a **coreutils**
multi-call binary fails with `coreutils: unknown program 'fish'`.)

But the mechanism is not sufficient. *Measured with a real Herdr pane root `exec`ing the wrapper:*

- **Design B — rejected.** `herdr agent start …` reported **`not an available shell`** for *both*
  pane variants — direct `nsenter`/Fish and the PTY-correct inner `script` form — and for host
  executables named `fish` **including a Nix-store binary copy**
  (`/nix/store/…-herdr-bwrap-pane-fish`). R12 is mandatory, so **design B fails this gate while
  PID namespaces are retained.** Dropping PID isolation, or changing Herdr, or writing a custom
  relay, are redesigns — not gates that have been passed.
- **Design A — accepted.** A pane root `exec`ed a Nix-store copy of `ssh` named `fish`, attached
  over `vsock-mux`, and got a real guest Fish prompt. `herdr agent start` **accepted the pane as
  an available shell and launched Pi in the guest.** Readiness detection then timed out, because
  the throwaway guest intentionally carried neither the Herdr guest relay nor the agent-state
  extension. That is a **broker/relay integration gate** (H7/H12), not a shell or PTY rejection.

This asymmetry — not latency, and not the weighting of R11 — is what decides §15.

---

## 6. Network: default-deny plus an allowlist

### 6.1 Design B — the part that had to be verified rather than assumed

With `--unshare-net` the sandbox has **only loopback**. *Measured* inside the holder:
`ip -o link show` lists `1: lo` and nothing else; `socat TCP:1.1.1.1:443` fails with
`Network is unreachable`. Default-deny is therefore enforced by the **absence of a route**,
not by policy — which answers the raw-IP-bypass question directly: there is no IP path to
bypass, and no `HTTP_PROXY`-style env-var dependence anywhere in the boundary. That is
strictly stronger than the current kit allowlist (which is enforced by sbx's network policy)
and strictly stronger than `srt`'s documented Linux weakness, where the proxy is reached via
env vars.

The egress path then has to be built. The mechanism is a pathname AF_UNIX socket, and it works
because of a kernel-documented asymmetry: network_namespaces(7) says netns isolation covers
"network devices, IPv4 and IPv6 protocol stacks, IP routing tables, firewall rules, …, port
numbers (sockets), and so on. In addition, network namespaces isolate the UNIX domain
**abstract** socket namespace (see unix(7))" — abstract only. unix(7) distinguishes `pathname`,
`unnamed` and `abstract` addresses, and for abstract notes "The name has no connection with
filesystem pathnames." A **pathname** socket is therefore reachable across a network namespace
boundary as long as its path is in your mount namespace.

*Measured, and this is the load-bearing experiment for design B:* a `socat UNIX-LISTEN` server
on the host, its directory bind-mounted into a holder created with `--unshare-net`, was
reachable from a pane attached with `--net`:

```
=== rw-bind socket dir: connect from inside unshared netns ===   HELLO-RW
=== ro-bind socket dir: connect from inside unshared netns ===   HELLO-RO
```

Both `--bind` and `--ro-bind` of the socket's directory work — `connect()` is not blocked by
`MS_RDONLY`, which means the socket directory can be mounted read-only.

Two practical constraints, one of them found the hard way:

- **`sun_path` is 108 bytes.** A first attempt using a socket under the long scratchpad path
  produced a socket named `pro` — silently truncated (*measured*). The workspace runtime
  directory must be short: `$XDG_RUNTIME_DIR/herdr/<short-id>/p.sock` (27 bytes in the test),
  not `$XDG_STATE_HOME/herdr-sandbox/workspaces/<20-hex>/run/…`.
- **`nono proxy` cannot be the far end directly.** *Measured*, `nono proxy --help` (0.71.0)
  offers `--listen <ADDR>` (default `127.0.0.1`), `--port <PORT>`, `--no-auth`,
  `--pass <PASSWORD>` / `NONO_PROXY_PASS`, `--max-connections`, `-p/--profile`. **There is no
  Unix-socket listener.** So the previous report's "hand the sandbox a Unix socket to
  `nono proxy`" does not work as written. What is required is a two-legged relay, which is
  precisely the shape Anthropic's `srt` uses on Linux (bwrap with the netns removed, proxies
  reached "via the filesystem over Unix domain sockets (using `socat` for bridging)"):

```
host netns:      nono proxy --listen 127.0.0.1 --port P --pass $NONO_PROXY_PASS
host relay:      socat UNIX-LISTEN:$RUNTIME/p.sock,fork  TCP:127.0.0.1:P
                   (bind-mounted read-only into the sandbox)
sandbox netns:   socat TCP-LISTEN:3128,bind=127.0.0.1,reuseaddr,fork  UNIX-CONNECT:/run/herdr/p.sock
guest env:       HTTPS_PROXY=http://127.0.0.1:3128  (+ Proxy-Authorization from --pass)
```

The in-namespace `socat` is part of the holder's own startup, not something a pane provides,
so it is inside the trust boundary of the unit. Note what this does *not* protect against: the
in-sandbox leg is a plain loopback listener, so **any process inside the sandbox can use the
proxy** — the proxy's allowlist is the boundary, not per-process identity. That is the same
property the current kit has.

**This relay was built and measured end to end** (record: `/tmp/herdr-bwrap-spike`, relay and
proxy logs). Results:

| probe | result |
| --- | --- |
| allowlisted host through the relay | **200** (example.com) |
| denied host through the relay | **403** (iana.org) |
| direct `curl` with the proxy env unset | fails — DNS resolution impossible, no route |
| unshared netns interface list | loopback only |

So design B's egress boundary is confirmed working and confirmed *not* env-var-dependent: gate
H6 passes for B. Design A's equivalent (the same proxy reached over vsock instead of a
bind-mounted socket) is **not yet built** — it remains gate H6 for A.

**Non-HTTP protocols.** An HTTP/CONNECT proxy covers TLS and HTTPS but not SSH, git-over-SSH,
or arbitrary TCP. Options, in order of preference: keep git over HTTPS (the current kit already
allowlists `github.com:443`/`api.github.com:443` and no SSH host); add a SOCKS5 leg as `srt`
does ("A SOCKS5 proxy handles all other TCP connections (SSH, database connections, etc.)");
or add one extra `socat` pair per required TCP destination, which is auditable but does not
scale. **DNS**: the sandbox has no resolver and no route, so names must be resolved by the
proxy — CONNECT with a hostname, or SOCKS5h. Do not bind-mount `/etc/resolv.conf` and expect
anything to work; if something does resolve, that is a leak to investigate.

### 6.2 Design A — tap, vsock, or proxy

Three shapes, and the choice is genuinely open:

1. **No tap at all + the same proxy pattern over vsock.** The guest gets no network interface;
   a guest-side relay forwards loopback TCP to the host over AF_VSOCK, and the host end feeds
   `nono proxy`. Same default-deny-by-absence property as design B, and vsock is already
   present for SSH attach. Most consistent with the rest of the design.
2. **Tap plus host firewalling.** `microvm-tap-interfaces@%i.service` exists and
   `hypervisorsWithNetwork = hypervisors`, so a tap per VM is fully supported. Enforcement then
   moves to host nftables rules per tap — root-owned, outside the user session, and a second
   policy language to keep in sync with the allowlist. Also gives the guest a real IP stack,
   which is more capability than the workload needs.
3. **Tap plus in-guest enforcement.** Rejected: the guest is assumed compromised (R11 exists
   precisely because guest root is reachable), so policy must not live there.

Recommendation: **(1)** for a prototype, because it keeps a single allowlist implementation
shared with design B and avoids root-owned nftables state per workspace.

---

## 7. Filesystem: store, closure, caches, home, clone, GC roots

### 7.1 Read-only host inputs (R4)

| | Design A | Design B |
| --- | --- | --- |
| `/nix` | virtiofs share `source = "/nix/store"`, `readOnly = true` → also flips `storeOnDisk` to false | `--ro-bind /nix /nix`; *measured*: `touch /nix/probe` → `Read-only file system` |
| HM generation + `.nix-profile` | additional read-only shares, or resolved inside the guest through the shared store | already reachable through `/nix`; the existing `HERDR_HOST_PROFILE` / `HERDR_HOST_HOME_FILES` indirection works unchanged |
| 4 caches | 4 read-only virtiofs shares with `cache` tuned per share | 4 `--ro-bind`s |
| Cost model | one virtiofsd process per share per VM (`microvm-virtiofsd@`), root-run | zero extra processes |

Design B's advantage here is not subtle: the caches and the store are the *same inodes* with no
daemon in the path. Design A's cost is 5+ root-run virtiofsd instances per workspace and a
metadata-heavy access pattern (`/nix/store` lookups by Fish, Nvim, Nix, Devenv) crossing a
virtio boundary. microvm.nix documents only that "Expect `virtiofs` to yield better performance
over `9p`" ([shares.html](https://microvm-nix.github.io/microvm.nix/shares.html)), which says
nothing about the absolute figure — so this was measured.

**Gate H2: measured, acceptable, and share tuning matters.** Identical `hyperfine`, `rg` and
`find` binaries (the guest can execute host store paths) against identical absolute targets;
10 runs after 2 warmups each.

Store share — a 21,477-file store path:

| workload | host | guest `cache=auto`, `posixAcl=true` | guest `cache=always`, `posixAcl=false` |
| --- | --- | --- | --- |
| `find -type f` | 15.3 ms ± 1.4 | 294.5 ms ± 40.2 (**19.2×**) | 111.0 ms ± 12.0 (**7.3×**) |
| `rg --files` | 13.3 ms ± 1.4 | 125.7 ms ± 11.0 (**9.5×**) | 61.5 ms ± 5.9 (**4.6×**) |

Writable share — a 2,156-file repo copy (representative of the clone):

| workload | host | guest default | guest tuned |
| --- | --- | --- | --- |
| `find -type f` | 5.0 ms ± 2.4 | 116.5 ms ± 28.6 (**23×**) | 37.1 ms ± 8.7 (**7.4×**) |
| `rg --files` | 4.9 ms ± 1.1 | 24.5 ms ± 4.9 (**5.0×**) | 7.9 ms ± 0.9 (**1.6×**) |

`nvim --headless +q` fell from 57.4 ms ± 11.7 to 29.6 ms ± 3.0 with tuning. **The host nvim
figure (63.6 ms ± 5.5) is not a valid comparison** — the host nvim carries the user's Home
Manager config and plugins while the guest's is bare nixpkgs neovim; compare the guest columns
to each other only.

Reading: `cache=always` plus dropping virtiofsd's `--posix-acl --xattr` buys 2–3×. After tuning,
ripgrep over a real repo is 7.9 ms against 4.9 ms on the host — not distinguishable in use. The
residual gap is on raw stat-heavy walks (`find`, ~7×). Two caveats: the spike's virtiofsd ran
**unprivileged** and logged `File handles do not appear safe to use, disabling file handles
altogether` (§4.3.6), so a root-run virtiofsd may do better and was **not** measured; and guest
`git` timings were never obtained (§10.1).

### 7.2 The private clone, path identity, and publication (R3)

Today: `sbx --clone` makes the private clone, the guest bind-mounts it at the host checkout
path via passwordless sudo (`herdr-sandbox-fish:12-26`), and commits are retrieved through the
sbx-managed remote.

**Design B.** The clone is an ordinary host directory, e.g.
`$XDG_STATE_HOME/herdr-sandbox/workspaces/<id>/clone`, created with a plain
`git clone --no-hardlinks` (or `--reference` for space, at the cost of a dependency on the
source repo's objects). Path identity is a single `--bind <clone> <checkout-path>` in the
holder's argument list — no in-guest sudo, no re-mount on restart, no mount that "does not
survive sandbox restarts". **Publication gets simpler than today**: the host can
`git fetch <clone-path>` directly, because the clone is a host path the user owns. The
sbx-managed remote disappears with nothing replacing it. This is design B's second-largest win
after latency.

**Design A.** Two options, and they differ sharply:

- *Writable virtiofs share.* Keeps host-side `git fetch` working, but drags in uid mapping: the
  VM runs as `User=microvm`, virtiofsd runs as root, and files the guest creates carry guest
  uids. Fixing that means virtiofsd `--translate-uid`/`--translate-gid`, which `asserts.nix`
  declares mutually exclusive with `posixAcl`, so `posixAcl = false` on that share. Workable,
  but it is now a uid-mapping design, and every file the agent writes is subject to it.
- *Block volume* (`microvm.volumes` with `autoCreate = true`). No uid mapping at all, clean
  guest-side semantics, and the mount point is whatever you declare — so path identity is
  free. But the host can no longer read the clone without loop-mounting the image, so
  **publication must go back over a channel**: `git fetch` over the vsock SSH connection, or a
  guest-side push to a host bare repo. That is roughly the complexity sbx's managed remote was
  hiding, reintroduced.

### 7.3 Private home (R6 storage)

Design B: `--bind <state>/home /home/agent` — *measured* to be a private directory invisible
to the rest of the sandbox's view. Design A: a guest path on a volume, entirely private by
construction. Both are fine; A is stronger, B is sufficient.

Note for design B: because `/home/agent` is a real host directory owned by uid 1000, any
same-UID host process can read it (§9.3). Credentials that must not sit on disk at all should
go through the proxy (§8 of the previous report), not into this directory.

### 7.4 Nix GC roots

Design A needs them and microvm.nix provides them explicitly: `microvm -c` creates
`/nix/var/nix/gcroots/microvm/$NAME → $DIR/current` and `…/booted-$NAME → $DIR/booted`. Those
are **root-owned paths**, so workspace creation touches `/nix/var/nix/gcroots` — a real
privilege requirement, not an incidental one.

Design B pins nothing new: the guest runs the host's own profile and Home Manager generation,
which are already GC roots (`herdr-sandbox.nix:36-37` resolves them via `readlink -f`). The one
new requirement is that a *running* workspace's paths must not be collected mid-session — the
holder's `bwrap` argument list references store paths, and a `nix-collect-garbage -d` that
removes the generation the panes are using would break a live workspace. A per-workspace
indirect GC root under `~/.local/state/nix/gcroots/` (user-owned, no privilege needed) is the
fix, and it is a genuine requirement rather than a nicety.

---

## 8. Limits: CPU, memory, PIDs, disk, I/O

*All measured on Tahani, 2026-08-11.* `user@1000.service` shows
`cgroup.controllers = cpu io memory pids`, with `cgroup.subtree_control = cpu memory pids`
initially. Setting `IOReadBandwidthMax` on a transient user unit caused systemd to enable the
missing controller — afterwards `subtree_control = cpu io memory pids` and the unit's cgroup
contained `io.max: 259:0 rbps=10000000 wbps=max riops=max wiops=max`, with
`IOReadBandwidthMax=/dev/nvme0n1 10000000` on the unit. So I/O limits **are** available to
design B without any privileged change.

| Limit | Current (sbx) | Design A | Design B |
| --- | --- | --- | --- |
| CPU quota | `--cpus 4` | `microvm.vcpu` (real vCPU count) | `CPUQuota=400%` → `cpu.max 200000 100000` observed for 200% (*measured*) |
| CPU pinning | — | vCPU/`AllowedCPUs` on the *system* unit | **Unavailable**: `cpuset` is not among the user session's controllers (*measured*) |
| Memory | `--memory 8g` | `microvm.mem` — a hard guest allocation | `MemoryMax=` → `memory.max` observed (*measured*); prefer `MemoryHigh` + `MemoryMax` per systemd.resource-control(5)'s own advice |
| PIDs | implicit (guest kernel) | implicit (guest kernel) | `TasksMax=` → `pids.max=512` observed (*measured*) |
| Disk | 20 GiB root + 20 GiB docker | `microvm.volumes` `size` — a real bound | **No native equivalent**: a bind-mounted directory has no quota. Needs a loopback ext4 image per workspace, or an XFS/btrfs project quota — an unsolved piece of design B |
| Disk I/O | — | host-side `IOReadBandwidthMax` on the microvm unit | `IOReadBandwidthMax=`/`IOWriteBandwidthMax=` (*measured* working) |

Two asymmetries worth stating plainly. Design A's memory limit is an *allocation* (the guest
gets what it gets, and the guest kernel OOM-kills inside), which is more predictable than
design B's `memory.max` (host kernel kills the tree, and systemd.resource-control(5) notes the
OOM killer "is invoked inside the unit"). Design A's disk bound is native; design B's is
missing and is the one requirement where B is structurally behind not just A but the status
quo.

### 8.1 Design B's cgroup design, corrected by measurement

An earlier revision said `nsenter --join-cgroup` was what placed pane processes under the
workspace's limits. **That is wrong** (§5.1): *measured*, it fails with
`write cgroup.procs failed: Permission denied` from a pane in a sibling cgroup, even with
`Delegate=yes` and user-owned cgroups.

The design that *does* work, measured in the spike:

```
herdr-ws-<id>.slice          <- owns MemoryMax, MemorySwapMax, TasksMax, CPUQuota
  ├── herdr-ws-<id>.service  <- the bwrap namespace holder
  └── herdr-pane-<n>.scope   <- one synchronous scope per pane
```

Membership comes from **unit placement under the slice**, not from `setns`-time migration.
`nsenter --cgroup` then only aligns the in-sandbox `/proc/self/cgroup` view.

*Measured* enforcement: a pane allocating 700 MiB under `MemoryMax=256M` with
`MemorySwapMax=0` was OOM-killed —

```
The kernel OOM killer killed some processes in this unit
```

— and **the holder remained active**, which is the desired blast radius (one pane dies, the
workspace survives). Gate H9's memory half therefore passes for B.

`Delegate=` still matters for the ownership split: "the control group tree at the level of the
unit's control group and above … is owned and managed by the service manager of the host, while
the control group tree below the unit's control group is owned and managed by the unit itself"
(systemd.resource-control(5)). And never grant the sandbox write access overlapping
`/sys/fs/cgroup` — nono's docs make the same point for the same reason, and the bwrap holder
should simply not bind `/sys` writable.

**Disk remains unresolved for design B.** No project-quota design was tested on Tahani's ext4
root, so a per-workspace disk bound still has no implementation (gate H9's disk half). Design A
gets this natively from `microvm.volumes` sizing.

---

## 9. Security boundary and attack surface

### 9.1 The boundary in one line each

**A:** guest kernel + VMM. A guest-root compromise must additionally break QEMU/cloud-hypervisor
(or the virtio device model, or virtiofsd — which runs as **root**) to reach the host. This is
R11, preserved.

**B:** host kernel + namespace configuration. A sandbox-root-equivalent compromise is already
running as uid 1000 on the host kernel; escape means a kernel bug, a namespace misconfiguration,
or a writable path that leads to host code execution. R11 is **not** preserved.

### 9.2 What the sandbox provably cannot do (design B), measured

Inside the holder, `/proc/self/status` shows `CapEff: 0000000000000000` and
`CapPrm: 0000000000000000` (*measured*) — consistent with bwrap(1)'s "By default no caps are
left in the sandboxed process."

Escape attempts from inside, *measured*:

```
nsenter -t 1 --mount --user true          → nsenter: reassociate to namespaces failed: Invalid argument
nsenter --net=/proc/1/ns/net true         → nsenter: reassociate to namespace 'ns/net' failed: Operation not permitted
```

Both outcomes are exactly what the documented rules predict. Joining the host netns needs
`CAP_SYS_ADMIN` in the user namespace owning it — the initial namespace — and the sandbox holds
capabilities only inside its own: "Having a capability inside a user namespace permits a process
to perform operations … only on resources governed by that namespace … Only a process with
privileges in the initial user namespace can perform such operations" (user_namespaces(7)).
And re-entering upward is barred outright: "It is not permitted to use `setns()` to reenter the
caller's current user namespace. This prevents a caller that has dropped capabilities from
regaining those capabilities via a call to `setns()`" (setns(2)); nsenter(1) mirrors this for
`--all`. Landlock's rule that "sandboxed threads … cannot modify filesystem topology, whether
via `mount(2)` or `pivot_root(2)`" is not what stops this — namespace capability scoping is.

### 9.3 What a same-UID host process can still do (design B) — by design, but state it

Everything. A process running as uid 1000 outside the sandbox can:

- `nsenter` **into** the workspace — the ownership rule that makes pane attach work grants it
  to *any* same-UID process, not only to Herdr;
- read and write the private clone, `/home/agent`, and the workspace state directory directly;
- connect to the bind-mounted proxy socket and use the workspace's egress allowlist;
- read the broker capability from `$XDG_STATE_HOME/herdr-sandbox/registrations/<sandbox>.json`
  (mode 600, uid 1000) and speak to the broker as that workspace;
- `ptrace` the holder, subject to `kernel.yama.ptrace_scope` (yama is loaded on Tahani —
  *measured* — but same-session same-UID tracing is typically permitted at scope 1).

So design B's boundary is strictly one-directional: it confines the agent, and it does not
partition the user. That is the same claim nono makes about itself, and it is the honest
framing for design B too. It also means **the scoped Herdr broker and its per-workspace
capability must be retained** in design B (as already corrected in the previous report):
neither file permissions nor `SO_PEERCRED` can distinguish one workspace's sandbox from another
same-UID process, so the capability is the only thing that binds a request to a `workspaceId`.

### 9.4 Concrete attack surface inventory

| Surface | A | B |
| --- | --- | --- |
| Kernel syscall surface reachable by agent code | guest kernel (own instance) | **host kernel, full** |
| VMM / device model | QEMU or cloud-hypervisor | — |
| virtiofsd | one **root** process per share per VM | — |
| Namespace configuration | not security-relevant | **the entire boundary**: one wrong `--bind` is a hole |
| Proxy | host process; guest reaches it over vsock | host process; sandbox reaches it via bind-mounted socket + in-namespace `socat` |
| Broker | host process + capability | host process + capability (**required**, §9.3) |
| Privileged host components on the workspace path | T1/T2: `microvm@`, `microvm-virtiofsd@` (root), `/var/lib/microvms`, `/nix/var/nix/gcroots`. T3: none, but you own the control plane | **none** |
| Attack surface of the attach path | guest `sshd` | `nsenter` (setuid-free, single exec) |

Note the trade in the last two rows: design A buys a kernel boundary by adding root-owned host
services and a root-run filesystem daemon per share. Design B has no privileged component at
all but no kernel boundary. There is no configuration of either that gets both — with one
partial exception worth flagging: T3 (§4.3.4) keeps the guest kernel boundary while dropping the
root-owned host units, because `/dev/kvm` is world-accessible on Tahani (*measured*
`crw-rw-rw-`). It pays for that with an unprivileged virtiofsd — **measured as blocked**, §4.3.6 — and a control plane
this repo would have to maintain.

### 9.5 Hardening design B beyond bwrap arguments

bwrap already gives: all capabilities dropped (*measured*), `--unshare-*` for every namespace,
and `--new-session` which "calls `setsid()`. This disconnects the sandbox from the controlling
terminal which means the sandbox can't for instance inject input into the terminal." bwrap(1)
is explicit that without it "it is recommended to use seccomp to disallow the `TIOCSTI` ioctl,
otherwise the application can feed keyboard input to the terminal which can e.g. lead to
out-of-sandbox command execution (see CVE-2017-5226)". Since panes attach with `nsenter` and
each pane brings its own PTY, `--new-session` on the *holder* is right, and each pane's
`nsenter` should get its own session too.

Beyond that, three additions worth prototyping:

- **A seccomp filter via `--add-seccomp-fd`.** bwrap(1): rules "in the form of a compiled cBPF
  program, as generated by `seccomp_export_bpf`", repeatable, "the kernel will evaluate them in
  reverse order". Minimum useful set: deny `TIOCSTI` (belt and braces with `--new-session`),
  deny `io_uring_setup`/`io_uring_enter`/`io_uring_register` — `srt` blocks these because
  "`IORING_OP_SOCKET` on Linux 5.19+ would otherwise bypass the `socket()` rule" — and
  optionally deny `socket(AF_INET*)` outright as a second layer behind the empty netns.
- **Landlock as an inner layer**, via `nono run --sandbox-policy landlock` inside the holder or
  a direct ruleset. This is the composition nono itself recommends and it buys per-path
  granularity inside the mount namespace that bind mounts cannot express.
- **`--json-status-fd`** for the holder's readiness and child-pid discovery, instead of
  scraping `cgroup.procs` to find the inner pid (which is what the experiments here did and is
  not something production code should rely on).

---

## 10. Lifecycle timings and operations

### 10.1 What is measured and what is not

Both designs were built and timed. **Keep the two measurement classes apart**: a *no-op* is the
cost of getting `true` to run; *prompt-ready* is the cost of reaching a shell that accepts input.
They differ by an order of magnitude and are not interchangeable.

#### No-op overheads

| Operation | Mean | Runs |
| --- | --- | --- |
| `sbx exec -u agent <running> true` (today's pane attach) | 4.799 s ± 0.035 | 3 + 1 warmup |
| same, with `SBX_NO_TELEMETRY=1` | 3.355 s ± 0.035 | 3 + 1 warmup |
| **A** — new vsock SSH session → `true` | **296.1 ms ± 39.2** (227–370) | 20 + 3 |
| **B** — `nsenter --preserve-credentials --user --mount --pid --uts --ipc --net --cgroup --wdns=/workspace -- true` | **1.9 ms ± 1.3** | 20 + 3 |
| `bwrap` cold start, full mount set → `true` (holder creation only) | 4.1 ms ± 1.7 | 20 + 3 |

The B figure now includes `--net --cgroup --wdns`, which the earlier 792.7 µs measurement omitted;
adding them roughly doubled it, and it carries hyperfine's sub-5 ms accuracy warning.

#### Prompt-ready — an actual Fish prompt

| Operation | Mean | Runs |
| --- | --- | --- |
| **A** — cold: fresh state dir → SSH-ready | **8.70 / 8.75 / 8.49 s** | 3 |
| **A** — cold: fresh state dir → PTY `fish -c` executed | **8.98 / 9.01 / 8.76 s** | 3 |
| **A** — warm: new session → PTY `fish -c` | **340.0 ms ± 33.4** (290–416) | 20 + 3 |
| **A** — warm: interactive fish to OSC 133;B prompt marker | 783 ms, single instrumented run | 1 |
| **B** — cold: transient service + namespace holder → actual Fish prompt | **219.5 ms** (186–248) | 10 |
| **B** — warm: attach to an actual interactive Fish prompt via inner `script` PTY | **131.1 ms ± 11.5** (109.4–151.0) | 20 + 3 |

**Label the A cold number honestly: 8.5–9.0 s is unoptimised.** Guest SSH host keys are
regenerated on every boot because the spike persisted no guest state; nothing was tuned for boot
time. Persisting `/etc/ssh` on the state share is the obvious first optimisation and is a
remaining gate, not a measured floor.

The B cold number is *not* comparable to A's on scope: it was taken with `TERM=dumb` and
**without `.agents/resume`**, so it excludes project provisioning that A's path would also have to
run. It is a floor for B, not an end-to-end figure.

#### Still not measured

- sbx **cold create**, so the 8.5–9.0 s figure has no status-quo baseline to sit against
- guest `git` operations in A (hyperfine got exit 127, then no timing — most likely git's
  dubious-ownership check, repo owned by uid 1000 and the guest session running as root)
- a **root-run** virtiofsd, which may be faster than the unprivileged one measured (§7.1)
- A's egress relay over vsock, broker, credentials, and resource limits — none built
- either design's prompt-ready time *including* `.agents/resume`
- design A's disk bound in practice (native mechanism exists); design B's disk bound at all

### 10.2 Stop, resume, restart, upgrade, GC

| | Design A | Design B |
| --- | --- | --- |
| Stop | `systemctl stop microvm@<id>` → `ExecStop=…/booted/bin/microvm-shutdown`; with cloud-hypervisor that is `ch-remote --unix-socket <api socket>` | `systemctl --user stop herdr-ws-<id>` with `KillMode=control-group` |
| Resume | restart the unit; guest boots again; volumes persist | restart the unit; **namespaces are new** |
| Unexpected restart | `Restart=always`, `RestartSec=5s` in `microvm@` — the guest reboots and existing SSH sessions die cleanly | **Danger**: if `Restart=` is set, existing panes are left `nsenter`-ed into dead namespaces and see a frozen or vanished world. **Use `Restart=no`** and let a dead workspace be an explicit re-create |
| Upgrade | T1: `microvm -u <name>` (with `-R` to restart). **T2: re-point every `current` symlink at the new shared runner and restart** — one build, N symlink swaps, and `booted` keeps recording what is actually running | the holder's argument list changes only when the Nix module changes; existing holders keep the old policy until restarted — needs a generation stamp like today's `state/provisioned/<sandbox>` |
| GC | T1: `/nix/var/nix/gcroots/microvm/{name,booted-name}` handled by `microvm -c`. **T2: one GC root for the shared runner**, plus care that a `booted` symlink pinning an older runner is also rooted | must add a user-owned indirect GC root per live workspace (§7.4) |
| Orphan cleanup | `microvm -l` (T1); for T2 the state dirs under `/var/lib/microvms` are the inventory, and `microvm -l`/`-u` will not know about them | `systemctl --user list-units 'herdr-ws-*'`; stale state dirs and stale registrations must be reaped, exactly as `state/provisioned/<sandbox>` is today |

T2's upgrade story is *better* than T1's, which is worth stating because it is counter-intuitive
for an unsupported composition: one shared runner means one build to review and N atomic symlink
swaps, instead of N evaluations that could silently diverge. The cost is that `microvm -u` is no
longer the tool doing it, so re-pointing and restart ordering become this repo's code.

The `Restart=` row is the most important operational difference. In design A a restart is a
guest reboot with the same identity; in design B a restart is a *new sandbox* wearing the old
name, and any pane still attached is silently orphaned. Design B must therefore treat holder
death as terminal and surface it (R10: fail closed, never fall back to a host shell).

---

## 11. Packaging, and how much current code survives

`herdr-sandbox.nix` today is: a Home Manager aspect exporting `herdrSandbox.shell`, a
`writeShellScript` that exports ~20 `HERDR_SANDBOX_*` variables and execs
`shell.fish`, a `systemd.user.services.herdr-sandbox` broker, plus two packages
(`package.nix` for the broker/kit, `sbx-package.nix` for the vendored CLI).

| Component | Design A | Design B |
| --- | --- | --- |
| `src/daemon.ts`, `src/herdr.ts`, `src/rpc.ts` (scoped broker) | **reuse as-is** | **reuse as-is** |
| `src/guest/herdr-relay.ts` | reuse; transport becomes vsock or a guest-side socket | **simplify**: the broker socket can be bind-mounted, so the relay may reduce to nothing (keep the capability, §9.3) |
| `systemd.user.services.herdr-sandbox` | reuse | reuse |
| `shell.fish` dispatcher (workspace→id mapping, provisioning stamp, registration write, env assembly) | **~70% reusable under T2**: creation becomes `mkdir` + `ln -s` + `systemctl start microvm@…` (a privileged helper), attach becomes `ssh vsock-mux/…`. Under T1 it is ~60%, because a Nix build lands on the workspace path | **~70% reusable**; creation becomes `systemd-run`, attach becomes `nsenter` |
| `sbx-package.nix` | delete | delete |
| `sbx-pane-shell` fish-named exec trick | **keep the idea verbatim** (§5.5) | **keep the idea verbatim** |
| `kit/spec.yaml` network allowlist | port to `nono proxy` profile or nftables | port to `nono proxy` profile |
| `kit/files/.../herdr-sandbox-fish` guest entrypoint | mostly **deleted**: no HM symlink mirror, no host-profile indirection, no `remap-session-home.fish`, no `apt-get` wait — a NixOS guest with the shared store needs none of it | mostly **deleted** too, and additionally the `sudo` bind-mount block goes away because the bind happens in the holder's argument list |
| Credential copy block (`shell.fish:120-147`) | unchanged risk profile; spike `nono proxy` per credential | same |
| New code required | **T2**: one `nixosConfigurations.herdr-workspace` (not one per workspace), a privileged provisioning helper (`mkdir`/`ln -s`/`systemctl start`), symlink-swap upgrade logic, publication channel if volumes are used. **T1** adds per-workspace flake plumbing; **QEMU** would add a CID allocator, cloud-hypervisor does not | `herdr-ws@.service` template, holder argument builder, seccomp blob, in-namespace socat supervision, disk-quota story (§8) |

Design B is packaged entirely as Home Manager (user units, user state). Design A requires
**NixOS system** configuration: `microvm.nixosModules.host`, `/var/lib/microvms`, the
`microvm`/`kvm` users, and root-owned GC roots — plus a privileged path for the user's Herdr
dispatcher to create a workspace, which today needs nothing privileged at all. In a
single-user config that is acceptable; it is still a change in kind.

The privileged step under T2 is small and auditable enough to be worth naming precisely, because
it is the whole of design A's privilege requirement: create a directory under
`/var/lib/microvms`, symlink `current` at a fixed store path, and start/stop
`microvm@ws-<id>.service`. That is a bounded polkit rule or a tiny setuid-free helper unit —
not "the dispatcher needs root". A `herdr-microvm-provision@.service` templated system unit,
startable by the user via polkit and taking only a validated `<id>`, keeps the dispatcher
unprivileged and is the shape to prototype.

---

## 12. Prototype file plans

Neither is written here; both are scoped so the work is estimable.

### Design A prototype

Shape: **T2 with cloud-hypervisor** — one shared runner, N state directories, stock host units.
Note there is exactly **one** `nixosConfigurations` attribute, not one per workspace, and no CID
allocator.

```
modules/features/ai/_herdr-microvm/
  flake-part.nix            # ONE nixosConfigurations.herdr-workspace (shared by all workspaces)
  guest/default.nix         # microvm.hypervisor = "cloud-hypervisor"; vcpu/mem;
                            #   vsock = { cid = 3; ssh.enable = true; }   (same CID for every VM;
                            #     host-facing identity is the relative notify.vsock — §4.3.3)
                            #   interfaces = [];                          (no tap → runner is reusable)
                            #   registerWithMachined = false;             (default; avoids UUID clash)
                            #   shares (absolute, shared):  /nix/store ro + the 4 caches ro
                            #   shares (RELATIVE, per-dir): source = "clone"  -> checkout path
                            #                               source = "home"   -> /home/agent
                            #   volumes (RELATIVE, per-dir): image = "home.img" if a volume is
                            #                               preferred over a share (§7.2)
  guest/herdr.nix           # guest broker relay over vsock, agent user, .agents/resume hook
  host.nix                  # microvm.nixosModules.host; autostart = [];
                            #   useNotifySockets left ON (CID is static, so notify works)
  provision.nix             # herdr-microvm-provision@.service (system, templated):
                            #   mkdir /var/lib/microvms/ws-%i; ln -sT <shared runner> current;
                            #   git clone into ws-%i/clone; + polkit rule so the user may
                            #   start/stop microvm@ws-%i and this unit, nothing else
  upgrade.nix               # re-point every current symlink at a new shared runner; restart policy
  gcroot.nix                # one GC root for the shared runner (+ any pinned `booted` runner)
  dispatcher.fish           # replaces shell.fish: id -> ws-<id>, ensure provisioned, ensure
                            #   started, attach; fail closed
  pane-shell.nix            # fish-named wrapper exec'ing
                            #   ssh vsock-mux/var/lib/microvms/ws-<id>/notify.vsock
modules/features/ai/herdr-microvm.nix   # NixOS + HM aspects (needs system-level config)
```

If gate H1 fails (a repeated CID is not tolerated across concurrent cloud-hypervisor VMs), the
delta is confined to two files: set `vsock.cid = null`, add `extraArgsScript.nix` emitting
`--vsock cid=$N,socket=notify.vsock` from a per-directory `cid` file, and set
`microvm.host.useNotifySockets = false`. That is the QEMU fallback shape too, with
`-device vhost-vsock-pci,guest-cid=$N` instead.

### Design B prototype

**Retained for reference only — design B failed H3b (§5.5) and is not a production track.** The
seams below are still accurate for the parts worth salvaging (egress relay, slice-based limits),
and two entries need the corrections from the spike: `unit.nix` must put the limits on a
workspace **`.slice`** with the holder and each pane scope underneath (not on the holder service),
and `attach.nix` must **not** use `--join-cgroup` and must wrap the guest command in an inner
`script` to allocate a sandbox PTY.

```
modules/features/ai/_herdr-bwrap/
  holder.nix                # builds the bwrap argv: ro-binds, private home, clone bind at checkout
                            #   path, --unshare-all + --share-none policy, --new-session,
                            #   --add-seccomp-fd, --json-status-fd; NO --die-with-parent
  seccomp.nix               # cBPF blob: TIOCSTI, io_uring_*, AF_INET* belt-and-braces
  unit.nix                  # herdr-ws@.service template: Type=exec, Restart=no,
                            #   KillMode=control-group, Delegate=yes,
                            #   MemoryMax/TasksMax/CPUQuota/IO*BandwidthMax, ExecStopPost cleanup
  egress.nix                # nono proxy user unit (--pass from a secret) + host socat leg;
                            #   in-namespace socat started by the holder; short $XDG_RUNTIME_DIR path
  attach.nix                # nsenter argv: --preserve-credentials --user --mount --pid --uts
                            #   --ipc --net --cgroup --wdns=<checkout>  (NOT --join-cgroup, §5.1)
  pane-shell.nix            # fish-named wrapper exec'ing the nsenter argv
  dispatcher.fish           # replaces shell.fish: id -> unit name, ensure clone, ensure unit,
                            #   write registration, attach; fail closed everywhere
  gcroot.nix                # per-workspace indirect GC root under ~/.local/state/nix/gcroots
modules/features/ai/herdr-bwrap.nix     # Home Manager aspect only
```

---

## 13. Benchmarks and hard gates

Executable, and none of them invent a number. `hyperfine --warmup 3 --runs 20` unless noted.

### Prompt-ready lifecycle (the measurement neither design has)

A PTY harness is required — `hyperfine` cannot see a prompt. Sketch:

```bash
# prompt-ready.sh: stop the clock on a sentinel the pane shell prints
#   usage: prompt-ready.sh <pane-command...>
exec script -qec "$* " /dev/null | \
  awk -v t0="$(date +%s.%N)" '/HERDR_PROMPT_READY/{printf "%.3f\n", systime()-t0; exit}'
```

with `HERDR_PROMPT_READY` emitted from the guest Fish `-C` startup command (the dispatcher
already passes one: `shell.fish:98-101`). Then:

```bash
# B1 cold create + first prompt
hyperfine --warmup 0 --runs 10 --prepare 'systemctl --user stop herdr-ws-BENCH || true' \
  'prompt-ready.sh herdr-pane-shell BENCH'
# B2 subsequent pane attach to prompt (holder already warm)
hyperfine --warmup 3 --runs 20 'prompt-ready.sh herdr-pane-shell BENCH'
# B3 attach no-op with the full flag set (compare against the 792 µs figure)
hyperfine --warmup 3 --runs 20 \
  'nsenter -t $(cat run/BENCH.pid) --preserve-credentials --user --mount --pid --uts --ipc --net --cgroup --wdns=/workspace -- /run/current-system/sw/bin/true'
# A1/A2 same two, with the pane command replaced by
#   ssh vsock-mux/var/lib/microvms/ws-BENCH/notify.vsock
# A0a T1 workspace build cost (the cost T2 removes; measure it to quantify what T2 buys)
hyperfine --warmup 0 --runs 5 'nix build --no-link .#nixosConfigurations."ws-BENCH".config.microvm.declaredRunner'
# A0b T2 provisioning cost: no evaluation at all on this path
hyperfine --warmup 1 --runs 10 --prepare 'sudo systemctl stop microvm@ws-BENCH; sudo rm -rf /var/lib/microvms/ws-BENCH' \
  'sudo systemctl start herdr-microvm-provision@ws-BENCH'
# A0c T2 shared-runner reuse: same CID, N concurrent VMs (gate H1 — PASSED, see §4.3.5)
for i in 1 2 3; do sudo systemctl start microvm@ws-BENCH$i; done
for i in 1 2 3; do ssh vsock-mux/var/lib/microvms/ws-BENCH$i/notify.vsock hostname -f; done
```

### Workload benchmarks (run identically in both, and on the host as a baseline)

```bash
nvim --headless --startuptime /dev/stdout +q            # store-read latency, the virtiofs canary
hyperfine 'nix build --no-link nixpkgs#hello'           # store + daemon path
hyperfine 'devenv shell -- true'                        # the real project entry cost
hyperfine 'git status' 'git switch -' -w 3              # clone I/O on a large repo
hyperfine --runs 5 'rg --files | wc -l'                 # metadata-heavy tree walk
```

### Hard gates — status after the spikes

✅ passed with evidence · ❌ failed · ⬜ not yet tested

| Gate | A (microvm.nix T2 / CH) | B (bwrap) |
| --- | --- | --- |
| **H1** shared-runner reuse + vsock CID | ✅ 4 concurrent VMs, one runner, `cid=3`, distinct boot ids, correct per-instance shares; kernel vsock never used (§4.3.5, §4.5) | n/a |
| **H2** store / metadata performance | ✅ acceptable **with tuning**: `rg --files` on a repo 7.9 ms vs host 4.9 ms; `find` ~7× (§7.1) | ✅ native host filesystem, no boundary |
| **H3a** multi-PTY + TUI fidelity | ✅ native: `tty`→`/dev/pts/0`, `/dev/tty` readable, 3 PTYs, Nvim clean exit (§4.4) | ✅ **only via an inner `script` PTY allocator**; plain `nsenter` fails `ttyname()` (§5.4) |
| **H3b** **Herdr `agent.start` accepts the pane** | ✅ accepted; **Pi launched in the guest**. Readiness timed out for lack of the guest relay → H12, not a shell rejection (§5.5) | ❌ **`not an available shell`** for both pane variants, incl. a Nix-store `fish`-named binary (§5.5) |
| **H4** checkout path identity | ⬜ | ⬜ (`--bind` mechanism verified, identity not asserted end to end) |
| **H5** clone publication | ⬜ | ⬜ |
| **H6** egress fail-closed + no proxy bypass | ⬜ vsock relay not built | ✅ 200 allowlisted / 403 denied / no route with proxy unset (§6.1) |
| **H7** broker scope + capability | ⬜ | ⬜ |
| **H8** credentials | ⬜ | ⬜ |
| **H9** limits: CPU/mem/PIDs **and disk** | ✅ mem/CPU/PIDs are guest-native; disk native via `microvm.volumes` sizing — ⬜ not exercised | ✅ memory: 700 MiB pane under `MemoryMax=256M` OOM-killed, holder survived (§8.1) · ❌ **disk: no design tested on ext4** |
| **H10** lifecycle recovery + GC | ⬜ | ⬜ |
| **H11** prompt-ready latency accepted | ⚠️ warm 340 ms PTY Fish is fine; **cold 8.5–9.0 s unoptimised** and has no sbx baseline (§10.1) | ✅ 131.1 ms warm, 219.5 ms cold — but scope-limited (no `.agents/resume`) |
| **H12** guest relay / agent-state integration | ⬜ **the remaining blocking gate for A** | ⬜ |

**H3b is the gate that decides the comparison.** It is mandatory (R12), it was tested with a real
Herdr pane rather than inferred, and design B failed it in both variants. Its failure is not
recoverable by tuning: the routes available are dropping PID isolation, changing Herdr, or writing
a custom relay — all redesigns.

---

## 14. Weighted decision matrix

**The weighted matrix is now subordinate to a gate result and is retained only for texture.**
R12/H3b is a mandatory requirement, design B fails it (§5.5), and no weighting of the remaining
criteria overrides a failed mandatory gate. What follows is therefore *not* the decision
procedure — it is a record of how the two compare on everything else.

Scores 0–5; weights are mine and not objective. Cells marked ⟳ changed on spike evidence, with
the pre-spike score in parentheses.

| Criterion | Weight | A: microvm.nix (T2, CH) | B: bwrap+nsenter |
| --- | --- | --- | --- |
| **R12 Herdr `agent.start`** | **gate** | **✅ pass (measured)** | **❌ fail (measured)** |
| R11 guest-kernel boundary | 5 | **5** | 0 |
| R2 many panes, one environment, real PTY | 5 | ⟳ **5** — measured native, no workaround | ⟳ 4 (3) — measured, but needs an inner `script` PTY allocator |
| R3 clone + path identity + publication | 4 | 3 (share→uid mapping, or volume→new channel) | **5** (host dir, `git fetch`) |
| R4 host `/nix` + caches read-only | 4 | ⟳ 4 (3) — measured; acceptable with share tuning | **5** (same inodes) |
| R7 default-deny egress | 4 | ⟳ 3 (4) — vsock relay **not built** | ⟳ **5** — relay measured 200/403, no bypass |
| R5/R6 broker + credentials | 3 | 4 | 4 |
| R8 limits incl. disk | 3 | **5** (native volume + guest mem) | ⟳ 3 — memory measured working; **disk still unresolved** |
| R9 tooling | 3 | 4 (NixOS guest, no `apt`) | 4 (host distro, no `apt`) |
| Pane attach latency (prompt-ready) | 3 | ⟳ 3 (2) — 340 ms measured | ⟳ **5** — 131 ms measured |
| Cold create latency | 2 | ⟳ 1 (2) — 8.5–9.0 s measured, unoptimised | ⟳ **5** — 219.5 ms measured |
| Privileged surface added | 3 | 2 — bounded to `mkdir`/`ln -s`/`systemctl start` behind a templated unit + polkit | **5** (none) |
| NixOS packaging fit | 2 | 4 (NixOS-native, but system-level) | **5** (Home Manager only) |
| Code reuse from this repo | 2 | 4 | **4** |
| Operational simplicity | 3 | 3 — one shared build, N directories | **4** (one lifecycle) |
| Maturity of the specific path | 2 | ⟳ 4 (3) — composition now demonstrated working | 3 |
| **Weighted total (excluding the gate)** | **48** | **173** | **190** |

So on the soft criteria B actually pulls *further* ahead than before (190 vs 173) — it is faster
on both latency classes and needs no privilege. And it is still the wrong choice, because it
cannot start a Herdr agent. That is the whole point of separating gates from weights: the earlier
revisions' "conditional tie at an R11 weight of ≈6.6" was an artefact of having no gate evidence,
and it no longer describes the decision.

Two of A's scores got *worse* on measurement (cold create, egress-not-built) and are the honest
residue: A is the slower, more privileged design that works.

---

## 15. Recommendation

**Choose design A: microvm.nix, tier T2, cloud-hypervisor. This is no longer conditional.**

The reason is a mandatory gate, not a preference: with a real Herdr pane, `herdr agent start`
**accepted** the microVM pane as an available shell and launched Pi in the guest, and **rejected**
both bubblewrap pane variants as `not an available shell` (§5.5). R12 is not negotiable, so design
B is out on functional grounds while PID namespaces are retained — and it happens to keep R11 as
well. Earlier revisions of this document offered a tie conditioned on how much the guest-kernel
boundary is worth; that conditional was an artefact of having no gate evidence and is withdrawn.

The shape, all of it now demonstrated working on Tahani: one shared prebuilt runner symlinked as
`current` into N per-workspace state directories under the **stock** host units; relative
`source`/`socket`/`image` strings resolving against each `WorkingDirectory`; no
`microvm.interfaces`; `registerWithMachined = false`; the same `vsock.cid` in every instance with
per-directory `notify.vsock`; the host `/nix/store` shared read-only with `cache = "always"` and
`posixAcl = false`; panes as `ssh vsock-mux/<abs per-instance socket>` behind a `fish`-named
wrapper. No `extraArgsScript` and no CID allocator are needed.

### Remaining gates before this ships

1. **H12 — guest relay and agent-state integration.** The only thing standing between the spike
   and a working agent: `agent.start` launched Pi but readiness detection timed out because the
   throwaway guest carried neither the Herdr guest relay nor the agent-state extension. This is
   the top priority and it is integration work, not a research question.
2. **Cold-boot optimisation.** 8.5–9.0 s is *unoptimised* and includes SSH host-key regeneration
   on every boot because the spike persisted no guest state. Persist `/etc/ssh` on the state
   share, then re-measure; also establish an sbx cold-create baseline, which does not exist.
3. **H6 — egress over vsock.** Design B's two-legged relay is proven (200/403, no bypass);
   A's vsock equivalent is not built.
4. **H4/H5 — path identity and clone publication.** Decide share-with-uid-translation versus
   block volume. Prefer the writable share so host-side `git fetch` keeps working; the volume
   path re-introduces the publication channel sbx's managed remote currently hides.
5. **H7/H8/H10** — broker scope, credentials, lifecycle/GC. Untested in either design.

Accept up front: root-owned system units and `/var/lib/microvms`, a root-run virtiofsd per share
per workspace, a bounded privileged provisioning helper, a composition that `microvm -c`/`-u`
will not manage, no `apt`, and warm pane attach at **~296 ms no-op / ~340 ms PTY Fish** rather
than the sub-millisecond figure bubblewrap offers.

### What to keep from design B

Not the design — the parts that are independently useful and already proven:

- the **two-legged AF_UNIX egress relay** and its allowlist verification method (§6.1), which
  ports to A's vsock transport;
- the **slice-based cgroup design** (§8.1), which is the correct shape for limits in *any*
  user-session component here, and the `--join-cgroup` correction that came with it;
- bwrap as a **defence-in-depth layer inside the guest** if per-path control is ever wanted
  around the agent process.

Keep `/tmp/herdr-bwrap-spike` as the control record. If Herdr's shell-acceptance rule ever
changes, B becomes viable again on latency grounds alone — it was 131 ms warm to an interactive
Fish prompt against A's 340 ms, and 219.5 ms cold against 8.5–9.0 s.

### Still do this first

`SBX_NO_TELEMETRY=1` removes ~1.9 s from every pane attach today (*measured*) for a one-line
change, and upstream #429 — if fixed — removes essentially all of the remaining tax with no
migration at all. Design A is worth building because it replaces an unfree binary with a stack
this repo controls while keeping the microVM boundary, **not** because it makes pane attach fast:
on warm attach it is ~14× faster than sbx today, and on cold create it is currently slower than
anything else measured here.

---

## 16. Sources

All accessed **2026-08-11**.

**microvm.nix** (MIT) — <https://github.com/microvm-nix/microvm.nix>
- [`lib/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/default.nix) — the eight hypervisors, `hypervisorsWithNetwork`
- [`lib/runner.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/runner.nix) — **`runtime_args=$(${extraArgsScript})` appended to the hypervisor argv**, `createVolumesScript`, machined registration, `share/microvm/*` metadata
- [`lib/runners/qemu.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/runners/qemu.nix) — `vhost-vsock-pci,guest-cid=` (host-global CID), QMP socket, virtiofs chardevs
- [`lib/runners/cloud-hypervisor.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/runners/cloud-hypervisor.nix) — `--vsock cid=…,socket=notify.vsock` emitted only when a CID is set, `--api-socket`, `ch-remote` shutdown, virtiofs-only `throw`
- [`lib/volumes.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/lib/volumes.nix) — `createVolumesScript`, per-instance `mkfs` of relative `image` paths
- [`nixos-modules/microvm/virtiofsd/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/virtiofsd/default.nix) — `--socket-path`/`--shared-dir` passed through verbatim, so relative values resolve per `WorkingDirectory`
- [`doc/src/shares.md`](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/shares.md) — "Source path can be absolute or relative to /var/lib/microvms/$hostName"; `/nix/store` sharing; `--translate-uid`/`posixAcl`; the overlay-upper-layer caveat
- [`nixos-modules/microvm/options.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/options.nix) — `shares` (`proto`, `readOnly`, `cache`, `socket`), `volumes` (`autoCreate`, `size`), `storeOnDisk`, `registerClosure`, `socket`, `vsock.cid`, `storeDiskType`
- [`nixos-modules/microvm/asserts.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/asserts.nix) — unique virtiofs sockets; `posixAcl` vs `--translate-uid/gid`
- [`nixos-modules/microvm/vsock-ssh.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/microvm/vsock-ssh.nix) — `ssh vsock/<CID>`, `ssh vsock-mux/<path>`, `microvm -s`
- [`nixos-modules/host/default.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/host/default.nix) — `microvm@`, `microvm-virtiofsd@` (root), `microvm-tap-interfaces@`, `User=microvm`/`Group=kvm`, `Restart=always`
- [`nixos-modules/host/options.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/nixos-modules/host/options.nix) — `stateDir = /var/lib/microvms`
- [`pkgs/microvm-command.nix`](https://github.com/microvm-nix/microvm.nix/blob/main/pkgs/microvm-command.nix) — `nix build …declaredRunner`, `/nix/var/nix/gcroots/microvm/$NAME`, `-c/-u/-r/-s/-l`
- [shares.html](https://microvm-nix.github.io/microvm.nix/shares.html), [intro](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/intro.md), [host.md](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/host.md)

**bubblewrap** (LGPL-2.0+) — <https://github.com/containers/bubblewrap>, `bwrap(1)` as installed (0.11.2): `--die-with-parent` (`PR_SET_PDEATHSIG`), `--cap-drop`/"By default no caps are left", `--new-session`/CVE-2017-5226, `--seccomp`/`--add-seccomp-fd`, `--unshare-*`, `--json-status-fd`; README "not a complete, ready-made sandbox".

**util-linux** — `nsenter(1)` as installed: `--preserve-credentials`, `--all` and the setns caveat, PID-namespace fork behaviour, `--join-cgroup`, `--root`/`--wd`/`--wdns`, `--env`, `--keep-caps`. Source: <https://github.com/util-linux/util-linux/blob/master/sys-utils/nsenter.1.adoc>

**systemd** — `systemd-run(1)`, `systemd.scope(5)`, `systemd.resource-control(5)`, `systemd.service(5)` as installed on Tahani: transient service vs scope semantics, `Type=exec` caveat, `Delegate=` ownership split, `CPUQuota=`/`MemoryMax=`/`TasksMax=`/`AllowedCPUs=`/`IOReadBandwidthMax=`. Also **`systemd-ssh-proxy(1)`** as installed — the `unix/`, `vsock/`, `vsock-mux/` target syntax and the statement that "cloud-hypervisor/firecracker … do not allow direct AF_VSOCK communication between the host and guests, and provide their own multiplexer over AF_UNIX sockets", which is the basis for §4.5's hypervisor choice. Source: <https://github.com/systemd/systemd/tree/main/man>

**cloud-hypervisor** — [`docs/vsock.md`](https://github.com/cloud-hypervisor/cloud-hypervisor/blob/main/docs/vsock.md): `--vsock cid=3,socket=/tmp/ch.vsock`, the reserved CID table, the host-side `CONNECT <port>` handshake over `UNIX-CONNECT`, and the "based on the Firecracker implementation" note — plus the `CONFIG_VHOST_VSOCK` line under "Kernel Requirements" that makes CID-reuse-across-VMs documented-plausible; **since resolved by measurement** (§4.5).

**Linux man-pages 6.18** (built from nixpkgs to read upstream text) — `setns(2)` user/mount/PID namespace permission rules, multithreaded restriction, no-reenter rule; `user_namespaces(7)` capability and owner rules; `network_namespaces(7)` "network namespaces isolate the UNIX domain **abstract** socket namespace"; `unix(7)` pathname vs abstract addresses and `sun_path[108]`.

**Anthropic sandbox-runtime** — <https://github.com/anthropic-experimental/sandbox-runtime> — prior art for the Linux proxy bridge ("via the filesystem over Unix domain sockets (using `socat` for bridging)"), the `io_uring` seccomp rationale, and the env-var-proxy weakness this design avoids.

**nono 0.71.0** — `nono proxy --help` (*measured*): `--listen`/`--port`/`--no-auth`/`--pass`, **no Unix-socket listener**; [networking docs](https://github.com/nolabs-ai/nono/blob/main/docs/cli/features/networking.mdx).

**Measured on Tahani, 2026-08-11 — component probes** — transient-service holder parentage/cgroup/limits; `io` controller enabled on demand (`io.max` written); `cpuset` absent at `user@`; `nsenter` credential requirement; `CapEff`/`CapPrm` zero inside; escape attempts (EINVAL / EPERM); `--unshare-net` reality check (`lo` only, "Network is unreachable"); AF_UNIX connect across netns through `--bind` and `--ro-bind`; `sun_path` truncation; cross-pane job visibility; `ttyname()` failure; `comm` from exec-path basename.

**Primary measurement record — design A**: `/var/tmp/herdr-microvm-spike/` — `results.md` (full
write-up), `flake.nix` + `guest.nix` (the configuration built), `logs/build*.out|err`,
`logs/ws-*.vm.log`, `logs/ws-*.virtiofsd.log`, `start-instance.sh` / `stop-instance.sh` /
`cold-start.sh` / `sshx.sh` / `rsh.sh` / `fish-prompt.exp` / `nvim-tui.exp`, `probes/`. Covers
§4.3.5, §4.3.6, §4.4, §4.5, §7.1, §10.1 and the design-A half of §13. Retained for review; note
it contains a throwaway SSH key (`id_spike`) trusted only by the now-stopped guests.

**Primary measurement record — design B**: `/tmp/herdr-bwrap-spike/` — `holder.sh` (the
transient-service holder argv, with no `--die-with-parent`), `cold-ms.txt` (10 cold prompt-ready
runs), `pane-1..3.log` (the three PTYs at `/dev/pts/2,0,1`), `nvim.log`, `host-relay.log`,
`nono-proxy.log`, `guest-relay.log`, `pane-shell.sh` / `pane-shell-direct.sh` (the two rejected
pane variants), `pane-fish-store` (the Nix-store `fish`-named binary that was also rejected).
Covers §5.1, §5.4, §5.5, §6.1, §8.1, §10.1 and the design-B half of §13.

**Herdr `agent.start` gate** — run against a real Herdr pane for both designs; result recorded in
§5.5. Design B: `not an available shell` for both variants. Design A: accepted, Pi launched in
the guest, readiness timed out for lack of the guest relay/agent-state extension.
