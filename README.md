# tmux Setup

This is my personal tmux configuration. It lives in this repository so I can
keep it versioned and reuse it across machines. It is tuned for running coding
agents (Claude Code, Codex, and opencode) in many sessions at once.

## Setup

Run the setup script from anywhere:

```sh
./setup.sh
```

The script:

- links `tmux.conf` to `~/.tmux.conf` (an existing regular file is backed up
  with a timestamp first)
- links the helpers in `bin/` into `~/.local/bin`
- merges the Claude Code and Codex hooks from `agents/` into
  `~/.claude/settings.json` and `~/.codex/hooks.json` (see
  [Agent status](#agent-status))
- links the opencode plugin into `~/.config/opencode/plugins`
- installs TPM and the configured plugins
- installs the Catppuccin theme into `~/.config/tmux/plugins/catppuccin/tmux`
  (outside TPM, because its repository name clashes with other themes)

Git is required to install TPM and Catppuccin, and `jq` is required to install
the agent hooks and persist agent sessions.

The script is safe to run again. It only rewrites an agent config when its hooks
differ from the ones in `agents/`, and it backs that file up first.

After setting it up, start a new tmux server or reload the configuration from an
existing session:

```sh
tmux source-file ~/.tmux.conf
```

## Status bar

The bar uses Catppuccin Mocha. Each tab is a number block and a name block:

- The number block's color shows the agent state in that window: blue while
  working, yellow while waiting for input, green when done, red on error, and
  gray when there is no agent or it is idle.
- The current tab's name block is white with dark bold text.
- The session name sits on a mauve block on the right and turns red while the
  prefix is active.

A finished agent's state resets once its pane gets focus.

## Agent status

`tmux-claude-status` stores an agent's state on its pane, which drives the tab
colors, the picker, and session restore. The helper does nothing outside tmux.
Each agent calls it from the integration in `agents/`:

| Agent | Integration | Installed into |
| --- | --- | --- |
| Claude Code | `agents/claude/hooks.json` | `~/.claude/settings.json` (merged) |
| Codex | `agents/codex/hooks.json` | `~/.codex/hooks.json` (merged) |
| opencode | `agents/opencode/tmux-agent-status.js` | `~/.config/opencode/plugins` (linked) |

The hook files hold only this repository's hooks. Setup merges them into each
agent's config: hook groups that call `tmux-claude-status` are replaced, and
every other setting and hook (permissions, plugins, other tools' hooks) is kept.
Codex asks you to trust new or changed hooks the next time it starts.

Hooks pass the state as the first argument and the hook's JSON on stdin, which
is where the session ID comes from:

| State | Claude Code | Codex | opencode |
| --- | --- | --- | --- |
| `ready` | `SessionStart` | `SessionStart` | plugin load |
| `working` | `UserPromptSubmit`, `PreToolUse` | `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | busy status, replies |
| `waiting` | `Notification` (permission or input prompts) | `PermissionRequest` | permission or question asked |
| `done` | `Stop` | `Stop` | session idle |
| `error` | `StopFailure` | | session error |
| `clear` | `SessionEnd` | `SessionEnd` | process exit |

Codex runs hooks from a shared app-server daemon instead of from the pane, so
its `TMUX_PANE` points at whichever pane started the daemon. For Codex payloads
the helper ignores `TMUX_PANE` and finds the pane itself: the one already tagged
with that session ID, or else the most recently active Codex pane in the same
directory.

## Key bindings

| Keys | Action |
| --- | --- |
| `prefix a` | Agent picker: every pane running an agent, across all sessions |
| `prefix Space` | Jump to the next waiting agent, or else a finished one |
| `prefix s` | Session list, with agent state dots when a session is expanded |
| `prefix L` | Switch to the last session |
| `prefix c` | New window in the current directory |
| `prefix \|` / `prefix -` | Split horizontally or vertically in the current directory |
| `prefix h/j/k/l` | Move between panes |
| `Option+Shift+Arrow` | Resize the current pane |
| `prefix G` | Lazygit in a popup |

In the tree views, state is shown as a dot in the same colors as the tabs.

## Session persistence

Save the current tmux environment with `prefix + Ctrl-s`. Restore the most
recent save with `prefix + Ctrl-r`. Saves include sessions, windows, panes,
layouts, working directories, and supported running programs. Pane contents
are not saved.

tmux-continuum also saves automatically every 15 minutes. Restoring stays
manual. Continuum skips autosaving while another tmux server is running, so a
leftover server (for example one started with a different `TMUX_TMPDIR`) turns
it off until that server exits.

Each agent's session ID is stored on its pane, so saving records an exact
resume command and several conversations in the same directory restore
independently:

| Agent | Restored with |
| --- | --- |
| Claude Code | `claude --resume <id>` |
| Codex | `codex resume <id>` |
| opencode | `opencode --session <id>` |

A pane whose agent has not reported an ID yet restores with `claude --continue`,
`codex resume --last`, or `opencode --continue`. Existing sessions must trigger
at least one hook or event after setup before their IDs can be saved.
Submitting a prompt is sufficient.

## Terminal integration

Extended keys are enabled so Shift+Enter reaches Claude Code as a newline, and
passthrough is enabled so agent desktop notifications reach the outer terminal.
