#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
config_source=$repo_root/tmux.conf
config_target=$HOME/.tmux.conf

if [[ -e $config_target && ! -L $config_target ]]; then
  backup=$HOME/.tmux.conf.backup-$(date +%Y%m%d-%H%M%S)
  cp -p "$config_target" "$backup"
  printf 'Backed up existing config to %s\n' "$backup"
fi

ln -sfn "$config_source" "$config_target"
printf 'Linked %s to %s\n' "$config_target" "$config_source"
