# tmux reference

[Back to README](../README.md)

Images show the running terminal interfaces with sample task names and values. See
[capture notes](images/README.md) for the source of each view.

## Installation and updates

[setup.sh](../setup.sh) connects this checkout to the following locations:

| Location | What setup installs or changes |
| --- | --- |
| `~/.tmux.conf` | Symlink to this checkout's `tmux.conf` |
| `~/.local/bin/tmux-*` | Symlinks for this project's helpers |
| `~/.claude/settings.json` | Merged status hooks and a status line if none exists |
| `~/.codex/hooks.json` | Merged status hooks |
| `~/.config/opencode/plugins/tmux-agent-status.js` | Symlink to the opencode integration |
| `~/.tmux/plugins/` | TPM and the configured tmux plugins |
| `~/.config/tmux/plugins/catppuccin/tmux` | Catppuccin, initially cloned at `v2.3.1` |

Setup backs up a regular `~/.tmux.conf` before replacing it and changed agent
JSON files before updating them. Backups sit beside the originals with a
`.backup-YYYYMMDD-HHMMSS` suffix. Existing symlinks are repointed, and helper
symlinks are replaced without backups. Unrelated agent settings and hooks are
preserved.

After updating or moving the checkout, rerun `./setup.sh`, reload the tmux
config, and restart agent sessions. Rerunning setup does not upgrade existing
TPM or Catppuccin clones. The log viewer uses `uv` to provide Python 3.11 or
newer and install `rich` on first use, which may need network access.

## Agent support

| Feature | Claude Code | Codex | opencode |
| --- | --- | --- | --- |
| Session picker, activity colors, and conversation restore | Yes | Yes | Yes |
| Main conversation logs | Yes | Yes | Not supported |
| Subagent and background task logs | Yes, from Claude task files | Not supported | Not supported |
| Tab tokens and cost | Transcript tokens and status-line cost | Transcript tokens and estimated API cost for known models | Not supported |
| Account usage | Plan limits or spend | Plan usage windows | Not supported |
| `NOW` tool activity in delivery runs | With agent-skills' heartbeat hook | Not populated by this integration | Not populated by this integration |

System resource usage can include any pane with agent status, including
opencode. The current Codex hooks do not map a failure event to the red error
state; Claude and opencode do. Status colors reflect reported events, so a
failed command does not necessarily turn every provider's tab red.

## Navigation, names, and clipboard

In `prefix s`, use Up/Down to select a row, `+` to expand, `-` to collapse,
Enter to jump, and `q` to close. `Ctrl-s` searches names and `v` toggles the
preview. Session names and window names come from tmux. Pane rows show the
command and the working directory's final path component, with an activity dot
when status is available.

`prefix Space` searches all sessions in the current tmux server for another
waiting pane, then a finished pane. Repeated presses cycle through matches;
failed panes are not included. With no other candidate, it reports
`No agents need you`.

`prefix ,` gives a window a fixed name. Otherwise tmux names it from the running
command, with Claude's numeric process name replaced by its pane title.
Windows sort by name, ignoring case, after creation or renaming; `prefix O`
sorts manually. Sorting closes number gaps and keeps the current window
selected, so window indexes and picker `WHERE` values can change.

Mouse support is enabled. Scroll or use `prefix [` to browse up to 100,000
lines of pane history. Select text and press `y` in copy mode to copy it to the
system clipboard; mouse selection also copies through tmux-yank. `prefix y`
copies the current line and `prefix Y` copies the pane's directory.

`prefix u` uses tmux-fzf-url to find links in the visible pane text. Filter the
list and choose a link to open it with the system's URL opener. It requires
`fzf` and `fzf-tmux`; the default search does not include older scrollback.

## Conversation logs

`prefix e` opens logs beside the current agent and leaves focus on the agent.
Press it again from either pane to close the logs. `prefix W` opens a tmux
window; `prefix C-e` opens a Ghostty window through AppleScript. Press `q` in
the viewer to close it. The agent-skills `/logs` command offers the same choices.

The source labels distinguish the main conversation, subagents, and background
commands. Tool results and formatted JSON appear alongside the messages.

![Conversation log with main messages, a JSON tool result, a reviewer subagent, background checks, and filter keys](images/conversation-logs.png)

| Display | Source |
| --- | --- |
| `Following session` | Conversation ID recorded on the agent pane |
| `transcript` | Matching Claude JSONL under `~/.claude/projects/`, or Codex rollout JSONL under `~/.codex/sessions/` |
| `tasks` | Claude's task-output directory under `/private/tmp/claude-<uid>/` or `CLAUDE_CODE_TMPDIR` |
| Time | Transcript timestamp in local time, or the time output is read when no timestamp exists |
| `main`, `agent …`, `bash …` | Main transcript or a task filename; task IDs are shortened in the label |
| `you`, `agent`, tool name, result | Message role and content parsed from the transcript |

| Key in the viewer | Action |
| --- | --- |
| `a` | Show all sources |
| `m` | Show the main conversation |
| `s` | Show subagents |
| `b` | Show background commands |
| `n` / `p` | Select the next / previous source |
| `r` | Toggle tool results |
| `j` | Toggle full / shortened JSON |
| `q` | Close the viewer |

Claude and Codex support main conversation logs. Claude also supports subagent
transcripts and background command output. opencode logs are not supported by
this viewer.

The viewer renders Markdown, clickable links and file paths, and formatted JSON
or Python dictionaries and lists. Tool results initially show up to 12 lines;
background JSON shows up to 24. New sources appear as they start.
The viewer starts with the last 48 KiB of each source, then follows new output;
it does not load the whole conversation. Filters change only the display and
do not alter transcript files. Pressing `q` closes the viewer, not the agent.

Opening logs needs a recorded conversation ID and local transcript or task
files. Start the agent in tmux and submit a prompt if it reports
`this pane has no agent session`. Custom transcript locations outside the
directories above are not discovered by this viewer.

To follow a known conversation outside tmux:

```sh
tmux-agent-logs follow <session-id>
```

`uv` installs the viewer's `rich` dependency on first use. If links are not
clickable after a config reload, reattach the tmux client so the `hyperlinks`
terminal feature takes effect.

## Usage displays

| Shortcut | Display |
| --- | --- |
| `prefix T` | Tokens and cost for agents in the current tab |
| `prefix v` | Account limits or spend for Claude and Codex |
| `prefix S` | System usage and the busiest agent process trees |

Press any key to close a usage popup; in account usage, `r` refreshes instead.
Account and system bars are green below 50%, yellow from 50%, and red from 80%.
These colors show usage thresholds, separately from agent activity colors.

### Tab tokens and cost

`prefix T` groups usage by agent in the current tab, including cached tokens and
the Codex usage limit when available.

<img src="images/tab-usage.png" width="360" alt="Tab usage popup showing sample Claude cost, total tokens, and cached tokens">

Claude's tab cost comes from its status-line payload. Codex's tab cost is an
estimate at configured API prices, marked `~`; it is not the ChatGPT subscription
bill. Unknown Codex models show tokens without a cost. Token totals include
cached input, and Claude totals include subagents.

| Field | Source |
| --- | --- |
| Agent name | Pane process name; Claude's numeric process name is displayed as `claude` |
| `Tokens` / `Cached` | Claude assistant-message usage, counted once per message ID across the main transcript and subagents; Codex's latest `token_count` totals |
| `Cost` | Claude's `total_cost_usd` status-line value, or a Codex estimate from uncached input, cached input, and output token prices in [tmux-agent-usage](../bin/tmux-agent-usage) |
| `5h limit` | Codex's primary usage-window percentage from its transcript. The label is fixed even if that window has another duration; use account usage for the returned window name |

The popup reads the latest usage saved on each pane. Claude updates it through
its status line; Codex updates it when status hooks include a transcript path.
It is a snapshot, so reopen it to see newer totals. Panes without saved usage
are omitted; an empty tab shows `No agent usage in this tab yet`.

Setup adds Claude's status line only when none is configured. If you keep your
own status line, it must call [tmux-claude-statusline](../bin/tmux-claude-statusline)
for Claude's tab usage to update.

### Account usage

`prefix v` shows usage across each account. This example shows Claude's monthly
spend and today's spend in UTC, followed by Codex's weekly usage and reset time.
All amounts and percentages are sample values.

<img src="images/account-usage.png" width="540" alt="AI usage popup showing Claude Spend and Today rows, plus Codex Weekly usage and its reset time, with sample values">

The account popup uses the agents' existing logins and caches responses for a
minute. Press `r` to refresh. On failure, it retains the last values with their
age. Claude shows plan limits or monthly spend, depending on the account;
Codex shows its plan usage windows.

| Field | Source |
| --- | --- |
| Claude `Spend` | The Claude usage API's used amount, limit, and percentage for the account |
| Claude `Today` | The daily-spend API, summed across products for the current UTC date; requires the separate web connection below |
| Claude plan windows | Five-hour or weekly utilization when returned by the account API instead of spend |
| Codex windows and reset time | The Codex account usage response, with labels derived from each window's duration and reset timestamp |

Claude authentication comes from its CLI credentials in macOS Keychain; Codex
uses `~/.codex/auth.json`. Responses are cached in
`${XDG_CACHE_HOME:-$HOME/.cache}/tmux-ai-usage/`. Reset times are calculated from the
API timestamps. Cached values at least five minutes old show their age. If no
cached data is available and fetching fails, sign in to the relevant agent and
refresh. These account totals cover more than the current tmux tab.

### System usage

`prefix S` shows machine usage, totals for agent process trees, and the processes
using the most CPU and memory.

<img src="images/system-usage.png" width="540" alt="System usage showing CPU at 43 percent, memory at 61 percent, disk at 90 percent, agent totals, and the busiest processes">

The system popup refreshes every few seconds. CPU per process is measured
against one core, so a process can exceed 100%. Memory includes app, wired, and
compressed pages. Disk usage is based on APFS container capacity and free space;
Finder can show more available space because it includes purgeable files.

| Display | Source and meaning |
| --- | --- |
| `CPU` | Machine-wide busy percentage from `iostat`, plus one-minute load and core count from `sysctl` |
| `Memory` | `vm_stat` page counts and total RAM from `sysctl`; this is used memory, not memory pressure |
| `Disk` | Capacity and available space from `df -k /` |
| `Agents` | Up to five status-bearing panes, sorted by CPU. Each row sums the pane's process and descendants from `ps`, including tools and servers it started |
| `Top CPU` / `Top memory` | The three busiest or largest processes across the machine, not just agents; memory is resident size from `ps` |

Agent row names come from `tmux session › window`. Process names are shortened
to fit. The status bar shows only machine-wide CPU, memory, or disk readings
at 80% or above; it does not show every process listed in the popup.

### Connect Claude daily spend

Enterprise daily spend needs a Claude web session in addition to the CLI login.
In your signed-in browser, copy the `sessionKey` cookie for `https://claude.ai`
from Developer Tools. Run this in your own terminal and paste it at the hidden
prompt:

```sh
tmux-ai-usage --connect-claude
```

Use the same account as the Claude Code login. The helper stores the web session
in macOS Keychain under `tmux-ai-usage-claude-web`. Open `prefix v` and press `r`
to fetch it. Reconnect when the web session expires.

Daily spend uses UTC dates and can lag behind current activity. Yesterday's
cached value is not shown as today's spend.

## Hooks and registry integration

[tmux-agent-status](../bin/tmux-agent-status) forwards session events to
agent-skills' `runs session` command. It caches identity and activity on the pane
for tab colors and layout restore. A valid session ID is recorded outside tmux
too. If `runs` is missing or fails, pane status still updates.

The registry normally lives at `~/.local/share/agent-sessions/sessions.sqlite3`.
Its storage options and migration rules belong to the
[agent-skills documentation](https://github.com/osvald0/agent-skills).
`TMUX_AGENT_RUNS` overrides the executable used by the hook, mainly for testing.

| Agent | Source | Installed location |
| --- | --- | --- |
| Claude Code | [hooks.json](../agents/claude/hooks.json) | `~/.claude/settings.json` |
| Codex | [hooks.json](../agents/codex/hooks.json) | `~/.codex/hooks.json` |
| opencode | [plugin](../agents/opencode/tmux-agent-status.js) | `~/.config/opencode/plugins` |

The JSON files and plugin define the event mappings. Hooks supply the activity
and provider as arguments, with session metadata on stdin. Exit events clear
only matching identities. opencode also uses a process owner to protect a
replacement session from a late exit.

Codex hooks run in a shared daemon, so its inherited pane can belong to another
session. The helper uses an existing session match, or a single unclaimed Codex
pane in the same directory. Ambiguous matches remain unbound instead of changing
an unrelated pane; their registered conversations remain available in `runs --all`.

## Notifications

Claude and opencode notify on waiting, completion, or error. Notifications are
skipped when the pane is already focused, and for Claude's idle notification
immediately after completion. Codex sends its own notifications.

The helper writes terminal notification sequences to the tmux client's terminal.
Ghostty displays these as macOS notifications while Ghostty is not focused.
Shift+Enter and modified keys are enabled through tmux's extended-key support.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| A conversation is missing from the picker | Look in `runs --all`; closed or unbound conversations are hidden from the normal list. |
| The picker command is missing | Install agent-skills' global tools and confirm `~/.local/bin/runs` exists. |
| Logs do not open | Rerun `./setup.sh` from the checkout and confirm `uv` is installed. |
| Tab usage is empty | Confirm Claude's status line calls the helper, or let Codex emit a status event with its transcript path. opencode has no tab-usage integration. |
| The `Today` row is missing or unavailable | Connect Claude daily spend, refresh with `r`, and check the UTC date. Expired web credentials need reconnecting. |
| `prefix u` cannot open its picker | Confirm `fzf` and `fzf-tmux` are installed and available to tmux. |

### Restore troubleshooting

| Symptom | Check |
| --- | --- |
| No recent automatic layout save | Continuum may not enable autosaving if another tmux server exists when the config loads. Check for leftover test servers or a separate `TMUX_TMPDIR`, then reload the config once only the intended server remains. |
| A restored pane resumes the wrong conversation | The saved pane may have had no session ID. Submit a prompt in the agent, then save the layout again. |

With an ID, restore uses `claude --resume <id>`, `codex resume <id>`, or
`opencode --session <id>`. Without one, it falls back to each tool's latest-session
continuation command. The registry keeps conversation metadata independently of
these layout snapshots.

## Checks

Run the shell suite from the repository:

```sh
bash -c 'for check in tests/*.sh; do bash "$check" || exit; done'
```

Run the hook and opencode integration checks:

```sh
python3 tests/agent-status.py && node --experimental-vm-modules tests/opencode-status.mjs
```

The Node test uses built-in module mocks and may print an experimental-module
warning. For the cross-project flow, pass the path to the matching agent-skills
checkout:

```sh
python3 tests/registry-integration.py /absolute/path/to/agent-skills/global/bin/runs
```

This test uses a temporary tmux server and explicit temporary database paths. It
checks registration, waiting indicators, disconnection, all-provider resume, and
legacy import preservation, then removes its server and fixtures.
