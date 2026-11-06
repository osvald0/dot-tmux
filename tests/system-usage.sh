#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/tmux-system-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
export PATH="$work/bin:$PATH"

cat > "$work/bin/tmux" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list-panes) printf '100\037work › APP-1 Fix login\n' ;;
  show) printf '#%s\n' "${3#@thm_}" ;;
  *) printf '#9399b2 #f9e2af #f38ba8 #a6e3a1 #a6adc8\n' ;;
esac
STUB
cat > "$work/bin/ps" <<'STUB'
#!/usr/bin/env bash
printf '  100     1   1.0   10240 zsh\n'
printf '  101   100  40.0  524288 claude\n'
printf '  102   101  15.5  102400 node\n'
printf '  200     1  90.0   51200 Google Chrome Helper (Renderer)\n'
printf '  300     1   0.5 2097152 mds_stores\n'
STUB
cat > "$work/bin/iostat" <<'STUB'
#!/usr/bin/env bash
printf '      cpu    load average\n us sy id   1m   5m   15m\n 10 10 80  1.00 1.00 1.00\n 30 13 57  1.00 1.00 1.00\n'
STUB
cat > "$work/bin/sysctl" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  '-n hw.memsize') printf '17179869184\n' ;;
  *) printf '{ 3.25 2.00 1.00 }\n8\n' ;;
esac
STUB
cat > "$work/bin/vm_stat" <<'STUB'
#!/usr/bin/env bash
printf 'Mach Virtual Memory Statistics: (page size of 16384 bytes)\n'
printf 'Pages wired down:                             100000.\n'
printf 'Pages purgeable:                               10000.\n'
printf 'Anonymous pages:                              500000.\n'
printf 'Pages occupied by compressor:                  50000.\n'
STUB
cat > "$work/bin/df" <<'STUB'
#!/usr/bin/env bash
printf 'Filesystem 1024-blocks Used Available Capacity iused ifree %%iused Mounted on\n'
printf '/dev/disk3s1s1 488281250 12000000 48828125 20%% 1 1 0%% /\n'
STUB
chmod +x "$work/bin/"*

output=$(bash "$repo_root/bin/tmux-system-usage" </dev/null)

[[ $output == *'CPU'*' 43%'*'load 3.2 on 8 cores'* ]] || {
  printf 'Expected CPU from the second iostat sample.\n%s\n' "$output" >&2
  exit 1
}
[[ $output == *'Memory'*' 61%'*'9.8 of 16 GB'* ]] || {
  printf 'Expected memory to count app, wired, and compressed pages.\n%s\n' "$output" >&2
  exit 1
}
[[ $output == *'Disk'*' 90%'*'50.0 GB free of 500 GB'* ]] || {
  printf 'Expected disk usage from the container size and free space.\n%s\n' "$output" >&2
  exit 1
}

[[ $output == *'work › APP-1 Fix login'*' 56%'*'622 MB'* ]] || {
  printf 'Expected an agent pane to sum its whole process tree.\n%s\n' "$output" >&2
  exit 1
}
[[ $output == *'Top CPU'*'Google Chrome Helper (Renderer '*' 90%'* ]] || {
  printf 'Expected the busiest process first, with its spaced name cut to fit.\n%s\n' "$output" >&2
  exit 1
}
[[ $output == *'Top memory'*'mds_stores'*'2.0 GB'* ]] || {
  printf 'Expected the largest process first in the memory list.\n%s\n' "$output" >&2
  exit 1
}

status=$(bash "$repo_root/bin/tmux-system-usage" --status)
[[ $status == *' Disk '*' 90% '* && $status != *CPU* && $status != *Memory* ]] || {
  printf 'Expected the status bar to show only usage at 80%% or more.\n%s\n' "$status" >&2
  exit 1
}
[[ $status == *'bg=#red'* ]] || {
  printf 'Expected status blocks to use the theme red.\n%s\n' "$status" >&2
  exit 1
}

printf 'System usage tests passed.\n'
