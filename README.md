# tmux Setup

This is my personal tmux configuration. It lives in this repository so I can
keep it versioned and reuse it across machines.

## Setup

Run the setup script from anywhere:

```sh
./setup.sh
```

The script links `tmux.conf` to `~/.tmux.conf`. If `~/.tmux.conf` is an existing
regular file, the script creates a timestamped backup before replacing it.

After setting it up, start a new tmux server or reload the configuration from an
existing session:

```sh
tmux source-file ~/.tmux.conf
```
