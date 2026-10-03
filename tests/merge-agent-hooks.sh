#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/tmux-hooks-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Load the merger without running setup or changing installed configuration.
awk '/^merge_agent_hooks[(][)]/ { copying = 1 } copying { print } copying && /^}/ { exit }' "$repo_root/setup.sh" > "$work/merger.sh"
source "$work/merger.sh"

cat > "$work/config.json" <<'JSON'
{
  "permissions": { "keep": true },
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [
        { "type": "command", "command": "$HOME/.local/bin/tmux-agent-status ready" },
        { "type": "command", "command": "echo keep-me" },
        { "type": "prompt", "prompt": "Keep this prompt" }
      ]
    }],
    "SessionEnd": [{ "hooks": [
      { "type": "command", "command": "tmux-claude-status clear" }
    ] }],
    "CustomEvent": [{ "hooks": [
      { "type": "command", "command": "echo custom" }
    ] }]
  }
}
JSON

merge_agent_hooks "$repo_root/agents/claude/hooks.json" "$work/config.json"
jq -e --slurpfile expected "$repo_root/agents/claude/hooks.json" '
  . as $actual |
  all($expected[0].hooks | to_entries[];
    . as $event | all($event.value[]; . as $group | ($actual.hooks[$event.key] | index($group)) != null)) and
  .permissions.keep == true and
  .hooks.SessionStart[0] == {
    matcher: "startup",
    hooks: [
      {type: "command", command: "echo keep-me"},
      {type: "prompt", prompt: "Keep this prompt"}
    ]
  } and
  .hooks.CustomEvent[0].hooks[0].command == "echo custom" and
  ([.hooks[][] | .hooks[] | .command // "" | select(contains("tmux-claude-status"))] | length) == 0
' "$work/config.json" >/dev/null

cp "$work/config.json" "$work/expected.json"
merge_agent_hooks "$repo_root/agents/claude/hooks.json" "$work/config.json"
cmp "$work/expected.json" "$work/config.json"

merge_agent_hooks "$repo_root/agents/codex/hooks.json" "$work/new.json"
jq -e --slurpfile expected "$repo_root/agents/codex/hooks.json" '. == $expected[0]' "$work/new.json" >/dev/null

printf 'Hook preservation, legacy replacement, repeat setup, and new config checks passed.\n'
