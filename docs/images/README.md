# Terminal capture notes

These PNGs render output from the project's terminal interfaces with sample
data. They are terminal previews, not desktop screenshots. The added title
above each capture identifies its view and shortcut. Colors use Catppuccin
Mocha, and text uses JetBrains Mono.

| Image | Source |
| --- | --- |
| [Session picker](session-picker.png) | The installed agent-skills `runs popup`, using an isolated SQLite registry and temporary tmux server |
| [Session tree](session-tree.png) | The `prefix s` binding in [tmux.conf](../../tmux.conf), with sample sessions and pane activity |
| [Agent status](agent-status.png) | The same server's status bar, showing all five activity colors and a waiting delivery run |
| [Conversation logs](conversation-logs.png) | [tmux-agent-logs](../../bin/tmux-agent-logs) message and filter renderers, with sample main, subagent, and background output |
| [Tab usage](tab-usage.png) | [tmux-agent-usage-popup](../../bin/tmux-agent-usage-popup), using the sample pane values from [agent-usage.sh](../../tests/agent-usage.sh) |
| [Account usage](account-usage.png) | [tmux-ai-usage](../../bin/tmux-ai-usage), using temporary cached plan responses |
| [System usage](system-usage.png) | [tmux-system-usage](../../bin/tmux-system-usage), using the sample process and machine values from [system-usage.sh](../../tests/system-usage.sh) |

The tmux captures load the repository's bindings and formats with the installed
Mocha palette. Plugin startup, automatic hooks, and live system polling are
disabled in the temporary server. No agent conversations or account credentials
are included.

When refreshing an image, run its interface with isolated sample data, preserve
the terminal colors, and check that its shortcut and labels still match the
docs. Keep account and system values synthetic. Check readability at the width
used in the README or reference, and update the alt text if the example changes.
