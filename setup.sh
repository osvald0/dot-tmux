#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
config_source=$repo_root/tmux.conf
config_target=$HOME/.tmux.conf
tpm_root=$HOME/.tmux/plugins/tpm
local_bin=$HOME/.local/bin

command -v jq >/dev/null 2>&1 || {
  printf 'jq is required to persist Claude Code sessions.\n' >&2
  exit 1
}

if [[ -e $config_target && ! -L $config_target ]]; then
  backup=$HOME/.tmux.conf.backup-$(date +%Y%m%d-%H%M%S)
  cp -p "$config_target" "$backup"
  printf 'Backed up existing config to %s\n' "$backup"
fi

ln -sfn "$config_source" "$config_target"
printf 'Linked %s to %s\n' "$config_target" "$config_source"

mkdir -p "$local_bin"
ln -sfn "$repo_root/bin/tmux-claude-status" "$local_bin/tmux-claude-status"
ln -sfn "$repo_root/bin/tmux-resurrect-claude-save" "$local_bin/tmux-resurrect-claude-save"

if [[ ! -d $tpm_root/.git ]]; then
  command -v git >/dev/null 2>&1 || {
    printf 'Git is required to install TPM.\n' >&2
    exit 1
  }

  mkdir -p "$(dirname "$tpm_root")"
  git clone https://github.com/tmux-plugins/tpm "$tpm_root"
fi

"$tpm_root/bin/install_plugins"
printf 'Installed tmux plugins.\n'
