import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SESSION = "11111111-1111-1111-1111-111111111111"


def verify(runs):
    with tempfile.TemporaryDirectory(prefix="registry-integration-") as temporary:
        folder = Path(temporary)
        legacy = folder / "legacy"
        legacy.mkdir()
        fixture = legacy / "old-run.json"
        original = json.dumps({"id": "old-run", "state": "done", "updated": 1})
        fixture.write_text(original)
        socket = str(folder / "tmux.sock")
        database = folder / "test.sqlite3"
        env = dict(
            os.environ,
            TMUX=f"{socket},0,0",
            RUNS_DIR=str(legacy),
            RUNS_DB=str(database),
            XDG_DATA_HOME=str(folder / "data"),
            TMUX_AGENT_RUNS=str(runs),
        )
        env.pop("RUNS_TMUX_PANES", None)
        subprocess.run(
            ["tmux", "-S", socket, "-f", "/dev/null", "new-session", "-d", "-s", "registry-test", "/bin/sh"],
            check=True,
        )
        try:
            env["TMUX_PANE"] = subprocess.check_output(
                ["tmux", "-S", socket, "display-message", "-p", "-t", "registry-test", "#{pane_id}"],
                text=True,
            ).strip()
            payload = json.dumps({
                "session_id": SESSION,
                "cwd": str(folder),
                "transcript_path": str(folder / "conversation.jsonl"),
            })

            def hook(status):
                subprocess.run(
                    [str(ROOT / "bin/tmux-agent-status"), status, "claude"],
                    input=payload, text=True, env=env, check=True,
                )

            def command(*args):
                return subprocess.check_output([str(runs), *args], env=env, text=True)

            hook("working")
            assert database.is_file(), "session hook must create the isolated SQLite registry"
            command("set", "integration-run", "--session", SESSION, "--agent", "claude", "--repo", "demo", "--phase", "Verify")
            hook("waiting")
            visible = command()
            assert "integration-run" in visible and "WAITING" in visible, visible
            assert "1 waiting" in command("bar")
            hook("clear")
            history = command("--all")
            assert "integration-run" in history and "old-run" in history, history
            resume = command("go", "integration-run")
            assert f"claude --resume {SESSION}" in resume, resume
            assert fixture.read_text() == original
            outside = dict(env, TMUX="", TMUX_PANE="")
            subprocess.run(
                [str(ROOT / "bin/tmux-agent-status"), "working", "codex"],
                input=payload, text=True, env=outside, check=True,
            )
            codex_resume = command("go", f"codex:{SESSION}")
            assert f"codex resume {SESSION}" in codex_resume, codex_resume
            assert f"claude --resume {SESSION}" in command("go", "integration-run")
            opencode_payload = json.dumps({"session_id": "ses_integration", "cwd": str(folder)})
            subprocess.run(
                [str(ROOT / "bin/tmux-agent-status"), "working", "opencode", "test-owner"],
                input=opencode_payload, text=True, env=env, check=True,
            )
            command("set", "opencode-run", "--session", "ses_integration", "--agent", "opencode")
            subprocess.run(
                [str(ROOT / "bin/tmux-agent-status"), "clear", "opencode", "test-owner"],
                input="{}", text=True, env=env, check=True,
            )
            assert "opencode --session ses_integration" in command("go", "opencode-run")
            print("Real tmux registration, waiting picker/bar, disconnect, all-provider resume, and preserved migration source passed.")
        finally:
            subprocess.run(["tmux", "-S", socket, "kill-server"], check=False, capture_output=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("runs", type=Path)
    verify(parser.parse_args().runs.resolve())
