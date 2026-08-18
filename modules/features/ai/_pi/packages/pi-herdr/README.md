# pi-herdr

Local fork of [`@ogulcancelik/pi-herdr` 0.4.0](https://github.com/ogulcancelik/pi-extensions/tree/main/packages/pi-herdr), preserving its MIT license.

This fork gives the user-facing Pi a deliberately narrow Herdr interface for spawning and controlling coding subagents. It is not a general Herdr terminal interface.

## Hard scope boundary

The extension registers only:

- `herdr_layout`, restricted to creating and finding the current workspace's background `subagents` tab and panes inside it.
- `herdr_agent`, restricted to coding agents hosted in those panes.

It does **not** register `herdr_pane`. The user-facing agent cannot use this extension to run shell commands, tests, builds, deployments, servers, logs, grep/search, file-printing commands, or any other ordinary process.

Runtime checks enforce the same boundary:

- layout creation is fixed to an unfocused tab named `subagents` in the current workspace;
- pane listing returns only panes in that tab;
- splitting requires a source pane in that tab;
- agent start and all subsequent agent interactions require a pane in that tab and current workspace;
- workspace creation/focus, tab focus, arbitrary pane inspection, raw pane input/output, and non-agent process actions are not exposed.

## Tools

### `herdr_layout`

| Action | Description |
|---|---|
| `tab_list` | List only `subagents` tabs in the current workspace |
| `tab_create` | Create an unfocused `subagents` tab in the current workspace |
| `pane_list` | List only panes in the current workspace's `subagents` tab |
| `pane_split` | Split a pane in that tab to host another subagent |

Created shells receive `HERDR_SKIP_DEVENV_AUTOACTIVATE=1` so they remain available for agent startup. No tool action can submit a command to those shells.

### `herdr_agent`

| Action | Description |
|---|---|
| `list` | List only subagents in the current workspace's `subagents` tab |
| `get` | Inspect one subagent |
| `start` | Start a supported coding agent in an allowed pane |
| `prompt` | Prompt a subagent and optionally wait for settlement |
| `wait` | Wait for a subagent lifecycle state |
| `read` | Read the subagent's resolved terminal stream |
| `send_keys` | Send validated UI keys to the subagent |

Agent targets are unique live names or hosting pane IDs. Lifecycle states are `working`, `blocked`, `done`, `idle`, and `unknown`.

`herdr_agent start` defaults to agent kind `pi`. Every Pi helper receives `--exclude-tools herdr_layout,herdr_pane,herdr_agent`; existing exclusions are merged. Helpers therefore remain leaf agents and cannot delegate recursively through Herdr.

Before startup, the extension marks the pane with the `subagent` metadata token used by the local Herdr UI.

## Typical workflow

1. List or create the `subagents` tab.
2. Use its root pane for the first helper; split a pane in that tab for additional helpers.
3. Start, prompt, wait for, and read the coding subagent through `herdr_agent`.
4. Use Pi's normal local tools—not Herdr—for all commands, checks, searches, file reads, and deployments.

## Installation

This fork is installed declaratively by `modules/features/ai/pi.nix` as `./packages/pi-herdr` under `~/.pi/agent`.

It activates only when Pi runs inside a Herdr-managed pane with `HERDR_ENV=1` and `HERDR_PANE_ID` set.

## Requirements

- Pi 0.80 or newer
- Herdr 0.7.5 or newer
- Pi running inside a Herdr pane

## License

MIT
