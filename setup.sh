#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
config_source=$repo_root/tmux.conf
config_target=$HOME/.tmux.conf
tpm_root=$HOME/.tmux/plugins/tpm
catppuccin_root=$HOME/.config/tmux/plugins/catppuccin/tmux
catppuccin_version=v2.3.1
local_bin=$HOME/.local/bin

command -v jq >/dev/null 2>&1 || {
  printf 'jq is required to install agent hooks and persist agent sessions.\n' >&2
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
for helper in tmux-agent-status tmux-resurrect-agent-save tmux-agent-next tmux-sort-windows tmux-ai-usage tmux-system-usage tmux-agent-usage tmux-agent-usage-popup tmux-claude-statusline; do
  ln -sfn "$repo_root/bin/$helper" "$local_bin/$helper"
done

# Merges an agent's hooks from agents/ into its config file. Hook commands that
# call tmux-agent-status (or its old name, tmux-claude-status) are replaced,
# and every other setting is kept.
merge_agent_hooks() {
  local source=$1 target=$2 merged created=

  mkdir -p "$(dirname "$target")"
  if [[ ! -s $target ]]; then
    printf '{}\n' > "$target"
    created=1
  fi

  # Leave the file untouched when our hooks already match, so tools that track
  # hooks by position (Codex trusts each one by index) do not ask again
  local ours='{
    hooks: ((.hooks // {})
      | with_entries(.value |= (map(.hooks |= map(select((.command // "") | test("tmux-(agent|claude)-status")))) | map(select(.hooks | length > 0))))
      | with_entries(select(.value | length > 0)))
  }'
  if [[ $(jq -S "$ours" "$target") == "$(jq -S . "$source")" ]]; then
    return
  fi

  merged=$(jq --slurpfile ours "$source" '
    .hooks = (
      (.hooks // {})
      | with_entries(.value |= (map(.hooks |= map(select((.command // "") | test("tmux-(agent|claude)-status") | not))) | map(select(.hooks | length > 0))))
      | with_entries(select(.value | length > 0))
    )
    | reduce ($ours[0].hooks | to_entries[]) as $event (.; .hooks[$event.key] += $event.value)
  ' "$target")

  if [[ $merged != "$(jq . "$target")" ]]; then
    [[ -n $created ]] || cp -p "$target" "$target.backup-$(date +%Y%m%d-%H%M%S)"
    printf '%s\n' "$merged" > "$target"
    printf 'Updated agent hooks in %s\n' "$target"
  fi
}

merge_agent_hooks "$repo_root/agents/claude/hooks.json" "$HOME/.claude/settings.json"
merge_agent_hooks "$repo_root/agents/codex/hooks.json" "$HOME/.codex/hooks.json"

# Claude only gives the session cost to its statusLine, so it shows tokens and
# cost there. An existing statusLine is kept.
claude_settings=$HOME/.claude/settings.json
if ! jq -e '.statusLine' "$claude_settings" >/dev/null 2>&1; then
  cp -p "$claude_settings" "$claude_settings.backup-$(date +%Y%m%d-%H%M%S)"
  jq '.statusLine = {type: "command", command: "$HOME/.local/bin/tmux-claude-statusline"}' "$claude_settings" > "$claude_settings.tmp" &&
    mv "$claude_settings.tmp" "$claude_settings"
  printf 'Added the tmux-claude-statusline statusLine to %s\n' "$claude_settings"
fi

opencode_plugins=$HOME/.config/opencode/plugins
mkdir -p "$opencode_plugins"
ln -sfn "$repo_root/agents/opencode/tmux-agent-status.js" "$opencode_plugins/tmux-agent-status.js"

if [[ ! -d $tpm_root/.git ]]; then
  command -v git >/dev/null 2>&1 || {
    printf 'Git is required to install TPM.\n' >&2
    exit 1
  }

  mkdir -p "$(dirname "$tpm_root")"
  git clone https://github.com/tmux-plugins/tpm "$tpm_root"
fi

if [[ ! -d $catppuccin_root/.git ]]; then
  mkdir -p "$(dirname "$catppuccin_root")"
  git clone -b "$catppuccin_version" https://github.com/catppuccin/tmux.git "$catppuccin_root"
fi

"$tpm_root/bin/install_plugins"
printf 'Installed tmux plugins.\n'
