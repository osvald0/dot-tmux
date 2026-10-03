# tmux Setup

Personal tmux configuration for running Claude Code, Codex, and opencode
across multiple sessions.

## Setup

Requires tmux, Git, and `jq`. Run from the repository:

```sh
./setup.sh
```

The script:

- links `tmux.conf` to `~/.tmux.conf` (an existing regular file is backed up
  with a timestamp first)
- links the helpers in `bin/` into `~/.local/bin`
- merges the Claude Code and Codex hooks into their configuration files
- links the opencode plugin into `~/.config/opencode/plugins`
- installs TPM and the configured plugins
- installs the Catppuccin theme into `~/.config/tmux/plugins/catppuccin/tmux`
  (outside TPM, because its repository name clashes with other themes)

Setup preserves unrelated settings and hooks, including commands in shared
hook groups. It backs up existing agent configs before changing them and
leaves matching configs untouched when run again.

After setting it up, start a new tmux server or reload the configuration from an
existing session:

```sh
tmux source-file ~/.tmux.conf
```

## Status bar

The bar uses Catppuccin Mocha:

```
 █ 0 █ claude █  █ 1 █ zsh █  █ 2 █ nvim █                           █ dotfiles █
```

Each tab is a number block followed by a name block. The current tab's name
block is white with dark bold text, and the others are dark gray. The session
name sits on a mauve block on the right and turns red while the prefix is
active.

The number block's color shows the state of the agent in that window:

| Color | State | Meaning |
| --- | --- | --- |
| Blue `#89b4fa` | working | The agent is running a prompt or a tool |
| Yellow `#f9e2af` | waiting | The agent needs you: a permission prompt or a question |
| Green `#a6e3a1` | done | The agent finished. Resets to idle once you focus its pane |
| Red `#f38ba8` | error | The turn failed |
| Gray `#9399b2` | ready or none | The agent is ready for a prompt, or no agent is running |

The session list (`prefix s`) and the agent picker (`prefix a`) show the same
states as a colored dot next to each window and pane.

## Agent status

`tmux-agent-status` stores an agent's state on its pane, which drives the tab
colors, the picker, and session restore. The helper does nothing outside tmux.
Each agent calls it from the integration in `agents/`:

| Agent | Integration | Installed into |
| --- | --- | --- |
| Claude Code | `agents/claude/hooks.json` | `~/.claude/settings.json` (merged) |
| Codex | `agents/codex/hooks.json` | `~/.codex/hooks.json` (merged) |
| opencode | `agents/opencode/tmux-agent-status.js` | `~/.config/opencode/plugins` (linked) |

Setup replaces this repository's hook commands, including their old
`tmux-claude-status` name. Codex asks you to trust new or changed hooks
the next time it starts.

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

## Session persistence

Save the current tmux environment with `prefix + Ctrl-s`. Restore the most
recent save with `prefix + Ctrl-r`. Saves include sessions, windows, panes,
layouts, working directories, and supported running programs. Pane contents
are not saved.

tmux-continuum also saves automatically every 15 minutes. Restoring stays
manual. Continuum skips autosaving while another tmux server is running, so a
leftover server (for example one started with a different `TMUX_TMPDIR`) turns
it off until that server exits.

Saved session IDs let conversations in the same directory restore independently:

| Agent | Restored with |
| --- | --- |
| Claude Code | `claude --resume <id>` |
| Codex | `codex resume <id>` |
| opencode | `opencode --session <id>` |

A pane whose agent has not reported an ID yet restores with `claude --continue`,
`codex resume --last`, or `opencode --continue`. Submit a prompt in existing
agent sessions after setup so their IDs can be saved.

## Notifications

`tmux-agent-status` sends a desktop notification when a Claude Code or
opencode agent is waiting for you, finishes, or stops with an error, for
example "Claude Code: notes › zsh finished". It skips the notification when
that pane is already in front of you, and when Claude reports an idle prompt
right after finishing.

Agents' own terminal notifications do not get through tmux, so the helper
writes the notification escape sequence (OSC 777) straight to the terminal
running the tmux client. Ghostty shows it as a macOS notification, but only
while Ghostty is not the focused app. Codex is skipped because it already posts
its own notifications through its desktop app.

## Terminal integration

Extended keys are enabled so Shift+Enter reaches Claude Code as a newline, and
passthrough is enabled so programs inside tmux can send escape sequences to
the outer terminal.
