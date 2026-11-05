#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/tmux-usage-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/cache/tmux-ai-usage"
export PATH="$work/bin:$PATH"
export XDG_CACHE_HOME="$work/cache"

cat > "$work/bin/tmux" <<'SH'
#!/usr/bin/env bash
printf '#9399b2 #f9e2af #f38ba8 #a6e3a1 #a6adc8\n'
SH
cat > "$work/bin/clear" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$work/bin/"*

cache=$XDG_CACHE_HOME/tmux-ai-usage
printf '%s\n' '{"spend":{"enabled":true,"percent":28,"used":{"amount_minor":69850},"limit":{"amount_minor":250000}}}' > "$cache/claude.json"
printf '%s\n' '{}' > "$cache/codex.json"
today=$(date -u +%F)

jq -n --arg today "$today" '{
  start_date: $today,
  end_date: $today,
  currency: "usd",
  series: [
    {bucket: $today, cost_minor_units: 1234},
    {bucket: $today, cost_minor_units: 56},
    {bucket: "2000-01-01", cost_minor_units: 999999}
  ]
}' > "$cache/claude_daily.json"

output=$(bash "$repo_root/bin/tmux-ai-usage" </dev/null)
[[ $output == *'Today'*'$12.90'*'UTC'* ]] || {
  printf 'Expected today’s spend to sum products, preserve cents, and exclude other dates.\n' >&2
  exit 1
}
[[ $output == *'$698 of $2,500'* ]] || exit 1

jq '.start_date = "2000-01-01" | .end_date = "2000-01-01"' "$cache/claude_daily.json" > "$work/yesterday.json"
cp "$work/yesterday.json" "$cache/claude_daily.json"
output=$(bash "$repo_root/bin/tmux-ai-usage" </dev/null)
[[ $output == *'Today'*'unavailable'* ]] || {
  printf 'Expected yesterday’s cached response to be unavailable today.\n' >&2
  exit 1
}

jq -n --arg today "$today" '{start_date: $today, end_date: $today, currency: "usd", series: []}' > "$cache/claude_daily.json"
output=$(bash "$repo_root/bin/tmux-ai-usage" </dev/null)
[[ $output == *'Today'*'$0.00'* ]] || exit 1

cat > "$work/bin/security" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *tmux-ai-usage-claude-web*) printf 'sk-ant-test-session\n' ;;
  *) exit 1 ;;
esac
SH
cat > "$work/bin/curl" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
if [[ ${FAIL_DAILY:-} == 1 ]]; then
  exit 22
fi
cat "$DAILY_RESPONSE"
SH
chmod +x "$work/bin/security" "$work/bin/curl"

export DAILY_RESPONSE="$work/response.json"
export HOME="$work/home"
mkdir -p "$HOME"
printf '%s\n' '{"oauthAccount":{"organizationUuid":"11111111-1111-1111-1111-111111111111"}}' > "$HOME/.claude.json"
jq --arg today "$today" '.series = [{bucket: $today, cost_minor_units: 3456}]' "$cache/claude_daily.json" > "$DAILY_RESPONSE"
touch -t 200001010000 "$cache/claude_daily.json"
output=$(bash "$repo_root/bin/tmux-ai-usage" </dev/null)
[[ $output == *'Today'*'$34.56'* ]] || exit 1

export FAIL_DAILY=1
touch -t 200001010000 "$cache/claude_daily.json"
output=$(bash "$repo_root/bin/tmux-ai-usage" </dev/null)
[[ $output == *'Today'*'$34.56'*'min ago'* ]] || exit 1

unset FAIL_DAILY
printf '%s\n' '{"error":"session expired"}' > "$DAILY_RESPONSE"
output=$(bash "$repo_root/bin/tmux-ai-usage" </dev/null)
[[ $output == *'Today'*'$34.56'*'min ago'* ]] || exit 1

printf 'Daily spend totals, UTC date boundaries, zero spend, refresh, failure caching, and monthly display checks passed.\n'
