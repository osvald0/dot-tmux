#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/tmux-agent-usage-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

usage=$repo_root/bin/tmux-agent-usage

expect() {
  [[ $1 == "$2" ]] || {
    printf 'Expected: %s\nGot:      %s\n' "$2" "$1" >&2
    exit 1
  }
}

# Codex: the last token_count wins, and cost splits uncached input, cached input, and output
codex=$work/rollout-2026-01-01T00-00-00-test.jsonl
cat > "$codex" <<'JSONL'
{"type":"turn_context","payload":{"model":"gpt-6.1-sol"}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":0,"output_tokens":10,"total_tokens":1010}},"rate_limits":{"primary":{"used_percent":3.0}}}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":9000000,"cached_input_tokens":8000000,"output_tokens":100000,"total_tokens":9100000}},"rate_limits":{"primary":{"used_percent":19.0}}}}
JSONL
expect "$("$usage" "$codex")" '9.1M (8.0M cached) · ~$3.80 · 19%'

sed -i '' 's/gpt-6.1-sol/some-new-model/' "$codex"
expect "$("$usage" "$codex")" '9.1M (8.0M cached) · 19%'

# Claude: a message repeated once per content block counts once, and subagents count
claude=$work/session.jsonl
mkdir -p "$work/session/subagents"
usage_line() {
  printf '{"type":"assistant","message":{"id":"%s","usage":{"input_tokens":%d,"cache_creation_input_tokens":%d,"cache_read_input_tokens":%d,"output_tokens":%d}}}\n' "$@"
}
{
  printf '{"type":"user","message":{"content":"hi"}}\n'
  usage_line msg_1 10 1000 50000 500
  usage_line msg_1 10 1000 50000 500
  usage_line msg_2 5 2000 60000 1000
} > "$claude"
usage_line msg_3 5 0 20000 200 > "$work/session/subagents/agent-1.jsonl"
expect "$("$usage" "$claude" 1.234)" '135k (130k cached) · $1.23'
expect "$("$usage" "$claude")" '135k (130k cached)'

# Claude's statusLine prints the same line it stores on the pane
expect "$(jq -n --arg t "$claude" '{transcript_path: $t, cost: {total_cost_usd: 0.5}}' |
  TMUX_PANE= "$repo_root/bin/tmux-claude-statusline")" '135k (130k cached) · $0.50'

expect "$("$usage" "$work/missing.jsonl")" ''

# Popup: only agent panes in the window, Claude named, Codex limit and estimate note shown
mkdir -p "$work/bin"
cat > "$work/bin/tmux" <<'SH'
#!/usr/bin/env bash
case $1 in
  display-message) printf '#a6adc8\n' ;;
  list-panes) printf '2.1.319\t2.0M (1.9M cached) · $1.31\nzsh\t\ncodex\t617k (542k cached) · ~$0.22 · 6%%\n' ;;
esac
SH
printf '#!/usr/bin/env bash\n' > "$work/bin/clear"
chmod +x "$work/bin/"*
popup=$(PATH="$work/bin:$PATH" "$repo_root/bin/tmux-agent-usage-popup" main:1 </dev/null | sed $'s/\033\\[[0-9;]*m//g')
expected=$'\n claude\n  Cost      $1.31\n  Tokens    2.0M\n  Cached    1.9M\n\n codex\n  Cost      ~$0.22\n  Tokens    617k\n  Cached    542k\n  5h limit  6%\n\n ~ estimate at API prices\n\n any key closes'
expect "$popup" "$expected"

printf 'Codex pricing, unknown models, Claude message dedupe, subagents, statusLine, and popup checks passed.\n'
