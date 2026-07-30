# tmux Setup

This is my personal tmux configuration. It lives in this repository so I can
keep it versioned and reuse it across machines.

## Setup

Run the setup script from anywhere:

```sh
./setup.sh
```

The script links `tmux.conf` to `~/.tmux.conf`, installs TPM when needed,
installs the configured plugins, and links the Claude Code status helper into
`~/.local/bin`. If `~/.tmux.conf` is an existing regular file, the script creates
a timestamped backup before replacing it. Git is required to install TPM, and
`jq` is required to persist Claude Code sessions.

Claude Code hooks can call `tmux-claude-status` to show `working`, `waiting`,
`done`, or `error` in the window tab. The helper does nothing when Claude Code is
running outside tmux.

After setting it up, start a new tmux server or reload the configuration from an
existing session:

```sh
tmux source-file ~/.tmux.conf
```

## Session persistence

Save the current tmux environment with `prefix + Ctrl-s`. Restore the most
recent save with `prefix + Ctrl-r`. Saves include sessions, windows, panes,
layouts, working directories, and supported running programs. Pane contents
are not saved.

Claude Code hooks pass each conversation ID to `tmux-claude-status`, which
associates it with the current pane. Saving tmux records an exact
`claude --resume <session-id>` command for each active Claude pane, so multiple
conversations in the same working directory restore independently. Existing
Claude sessions must run at least one configured hook after setup before their
conversation IDs can be saved. Submitting a prompt is sufficient.
