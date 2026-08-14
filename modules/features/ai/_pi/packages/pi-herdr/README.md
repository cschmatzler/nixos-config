# pi-herdr

Local fork of [`@ogulcancelik/pi-herdr` 0.4.0](https://github.com/ogulcancelik/pi-extensions/tree/main/packages/pi-herdr), preserving its MIT license.

Pi-native tools for controlling [Herdr](https://github.com/ogulcancelik/herdr) layouts, terminal panes, and coding agents.

## Local fork behavior

`herdr_agent start` defaults to agent kind `pi`. Every Pi helper receives `--exclude-tools herdr_layout,herdr_pane,herdr_agent`. Existing tool exclusions are merged, so recursive delegation is prevented through the normal Pi tool path without changing the helper's system prompt or trying to sandbox its process.

The proactive delegation policy lives in the Herdr tools' prompt guidelines. Because those tools are excluded from Pi helpers, only the user-facing Pi receives that policy.

Before starting an agent, the extension marks its pane with the `subagent` metadata token. The local Herdr configuration renders that token as a bold, accent-colored leading `↳ subagent` label in the Agents panel, while the local Herdr patch excludes marked panes from Spaces-panel state aggregation and completion/attention notifications.

Herdr-created shells receive `HERDR_SKIP_DEVENV_AUTOACTIVATE=1`, keeping the shell idle and available for agent startup. Commands that need the project environment can run through `devenv shell -- …`.

Other agent kinds keep their native arguments unchanged.

## Installation

This fork is installed declaratively by `modules/features/ai/pi.nix` as `./packages/pi-herdr` under `~/.pi/agent`.

The extension activates only when Pi runs inside a Herdr-managed pane with `HERDR_ENV=1` and `HERDR_PANE_ID` set.

This package provides structured Pi tools only. It does not bundle Herdr's standalone agent skill. Install that skill separately when you want direct access to the complete installed CLI.

## Execution model

Herdr exposes three distinct primitives:

- Layout organizes terminal locations. Workspaces contain tabs, and tabs contain panes.
- Pane controls a raw terminal containing a shell, test, server, build, log, or other ordinary process.
- Agent controls a recognized coding agent currently occupying a pane.

A pane exists independently of an agent. Starting an agent requires an existing pane at an available interactive shell prompt and never creates or changes layout.

The extension registers one tool for each primitive.

### `herdr_layout`

Use `herdr_layout` to inspect and create workspaces, tabs, and pane topology.

| Action | Description |
|---|---|
| `current` | Inspect the pane running the current Pi process |
| `workspace_list` | List workspaces |
| `workspace_create` | Create a workspace, first tab, and root pane |
| `workspace_focus` | Focus a workspace |
| `tab_list` | List tabs |
| `tab_create` | Create a tab and root pane |
| `tab_focus` | Focus a tab |
| `pane_list` | List panes in a workspace |
| `pane_layout` | Inspect pane geometry |
| `pane_split` | Split an existing pane |

Creation defaults to the caller pane's foreground working directory and preserves UI focus. When `pane_split` omits a direction, the tool chooses right for a sufficiently wide pane and down for a narrow or tall pane.

Workspace, tab, and pane IDs are opaque. Always use IDs returned by Herdr instead of constructing them.

### `herdr_pane`

Use `herdr_pane` for ordinary commands and intentional raw terminal control.

| Action | Description |
|---|---|
| `get` | Inspect a pane |
| `run` | Submit a shell command atomically with Enter |
| `read` | Read terminal output |
| `wait_output` | Wait for literal or regular-expression output |
| `send_text` | Send literal text without Enter |
| `send_keys` | Send logical terminal keys |
| `close` | Close a pane other than the pane running Pi |

`wait_output` searches existing output immediately before waiting for future output. Use `recent-unwrapped` for logs and transcripts.

Pane actions do not validate coding-agent identity or interpret agent lifecycle. Use `herdr_agent` when a pane contains a recognized coding agent.

### `herdr_agent`

Use `herdr_agent` to control a recognized coding agent by unique live name or by its hosting pane ID.

| Action | Description |
|---|---|
| `list` | List recognized agents |
| `get` | Inspect an agent |
| `start` | Start a supported agent in an existing available shell pane |
| `prompt` | Submit a prompt and optionally wait for settlement |
| `wait` | Wait for lifecycle state |
| `read` | Read the resolved agent terminal stream |
| `send_keys` | Send validated logical keys to the agent UI |
| `focus` | Focus the agent's pane |
| `rename` | Set or clear a live agent name |

Agent targets accept a unique live agent name or the pane ID currently hosting that agent. They do not accept terminal IDs or bare agent-kind labels.

Lifecycle states are:

- `working`: actively processing
- `blocked`: waiting for approval or an answer
- `done`: ready after unseen background work completed
- `idle`: ready and considered seen
- `unknown`: present, but lifecycle cannot be classified confidently

`prompt` waits by default and settles on the first `idle`, `done`, or `blocked` state unless `until` narrows the accepted states. A prompt submitted from a non-working state must produce an observed lifecycle change within five seconds or Herdr returns `agent_prompt_stalled`.

## Typical workflows

Start a coding agent in a sibling pane:

```json
{ "action": "pane_split" }
```

Use the returned pane ID:

```json
{
  "action": "start",
  "name": "reviewer",
  "kind": "pi",
  "pane": "w1:p2"
}
```

Prompt it and wait for settlement:

```json
{
  "action": "prompt",
  "target": "reviewer",
  "prompt": "Review the current diff and report only actionable findings.",
  "timeout": 120000
}
```

Read the result:

```json
{
  "action": "read",
  "target": "reviewer",
  "source": "recent-unwrapped",
  "lines": 120
}
```

For an ordinary command, split a pane with `herdr_layout`, submit the command with `herdr_pane run`, then use `herdr_pane wait_output` or `herdr_pane read`.

## Invocation policy

The user-facing Pi may use Herdr proactively for substantive work. Helpers are single-level leaf agents and cannot delegate through this extension.

Helper agents run in one background tab named `subagents` in the current workspace and working directory. The first helper uses the tab's root pane; additional helpers split panes only inside that tab. After a helper settles and its result is read and incorporated, the user-facing Pi closes that helper's pane. Focus remains with the user-facing Pi.

## Output limits

Read output is truncated to the last 2,000 lines or 50KB, whichever is reached first.

Full-screen agents may render through the terminal's alternate screen. Rows that leave that screen do not enter Herdr's host scrollback. If increasing `lines` does not reveal the complete response, ask the agent to write its response to a temporary Markdown file and read that file directly.

## Requirements

- Pi 0.80 or newer
- Herdr 0.7.5 or newer
- Pi running inside a Herdr pane

## License

MIT
