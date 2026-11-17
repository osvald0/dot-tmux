# Terminal capture notes

These PNGs capture the running tmux interfaces with sample task names, messages,
and values. Terminal cells are rendered as PNGs with JetBrains Mono; these are
not desktop screenshots. The captures preserve the actual popup borders,
dimensions, labels, spacing, and source tags. There are no added title banners.
Popups use Catppuccin Mocha over a Dracula terminal background.

| Image | Source |
| --- | --- |
| [Session picker](session-picker.png) | The installed agent-skills `runs popup`, using an isolated SQLite registry and temporary tmux server |
| [Session tree](session-tree.png) | The `prefix s` binding in [tmux.conf](../../tmux.conf), with sample sessions and pane activity |
| [Agent status](agent-status.png) | The same server's status bar, showing all five activity colors and a waiting delivery run |
| [Conversation logs](conversation-logs.png) | The running [tmux-agent-logs](../../bin/tmux-agent-logs) viewer, reading sample transcript and task files |
| [Tab usage](tab-usage.png) | [tmux-agent-usage-popup](../../bin/tmux-agent-usage-popup) in its configured 36 by 14 popup, with sample Claude pane values |
| [Account usage](account-usage.png) | [tmux-ai-usage](../../bin/tmux-ai-usage) in its configured 54 by 13 popup, with sample Claude monthly and daily spend and Codex weekly usage |
| [System usage](system-usage.png) | [tmux-system-usage](../../bin/tmux-system-usage), using the sample process and machine values from [system-usage.sh](../../tests/system-usage.sh) |

The tmux captures load the repository's bindings and formats with the installed
Mocha palette. Plugin startup, automatic hooks, and live system polling are
disabled in the temporary server. The account example follows the Spend, Today,
and Weekly layout, using temporary cached responses with dummy values. No real
conversations, account amounts, or credentials are included.

When refreshing an image, run the full interface in tmux with isolated sample
data. Match the account's displayed fields before replacing amounts and limits.
Keep the configured popup size, borders, colors, and default controls. Use
descriptive task names in the picker, tree, and tabs. Check readability at the
width used in the docs, and update the alt text if the example changes.
