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
a timestamped backup before replacing it. Git is required to install TPM.

Claude Code hooks can call `tmux-claude-status` to show `working`, `waiting`,
`done`, or `error` in the window tab. The helper does nothing when Claude Code is
running outside tmux.

After setting it up, start a new tmux server or reload the configuration from an
existing session:

```sh
tmux source-file ~/.tmux.conf
```
