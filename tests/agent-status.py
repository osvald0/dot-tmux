import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SESSION = "11111111-1111-1111-1111-111111111111"
OTHER_SESSION = "22222222-2222-2222-2222-222222222222"

TMUX = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

file = Path(os.environ["TMUX_TEST_STATE"])
state = json.loads(file.read_text())
args = sys.argv[1:]
command = args[0]
if command == "list-panes":
    print(state.get("listing", ""))
elif command == "show-options":
    print(state["options"].get(args[-1], ""))
elif command == "set-option":
    if "-pqu" in args:
        state["options"].pop(args[-1], None)
    else:
        state["options"][args[-2]] = args[-1]
    state["writes"].append(args)
    file.write_text(json.dumps(state))
elif command == "display-message":
    if args[-1] == "#{socket_path}":
        print("/tmp/tmux-test/socket")
    elif args[-1] == "#{pane_title}":
        print("Test conversation")
    elif args[-1]:
        print("work")
'''


REGISTRY = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

with Path(os.environ["REGISTRY_CALLS"]).open("a") as file:
    file.write(json.dumps({
        "args": sys.argv[1:],
        "payload": json.load(sys.stdin),
        "pane_state": json.loads(Path(os.environ["TMUX_TEST_STATE"]).read_text())["options"],
    }) + "\n")
sys.exit(int(os.environ.get("REGISTRY_FAIL", "0")))
'''


class AgentStatusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-status-test-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.state = self.folder / "state.json"
        self.state.write_text(json.dumps({"options": {}, "writes": []}))
        tool = self.folder / "tmux"
        tool.write_text(TMUX)
        tool.chmod(0o755)
        self.calls = self.folder / "registry.jsonl"
        registry = self.folder / "runs"
        registry.write_text(REGISTRY)
        registry.chmod(0o755)
        self.env = dict(
            os.environ,
            TMUX_AGENT_RUNS=str(registry),
            REGISTRY_CALLS=str(self.calls),
            PATH=f"{self.folder}:{os.environ['PATH']}",
            TMUX_TEST_STATE=str(self.state),
            TMUX_PANE="%1",
        )

    def run_status(self, status, agent="claude", payload=None, owner=""):
        return subprocess.run(
            [str(ROOT / "bin/tmux-agent-status"), status, agent, owner],
            input=json.dumps(payload or {}), text=True, capture_output=True, env=self.env,
        )

    def saved(self):
        return json.loads(self.state.read_text())

    def seed(self, options, listing=""):
        self.state.write_text(json.dumps({"options": options, "writes": [], "listing": listing}))

    def test_records_agent_type_with_session(self):
        result = self.run_status("working", payload={"session_id": SESSION})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.saved()["options"].get("@agent_type"), "claude")
        self.assertEqual(self.saved()["options"]["@agent_session_id"], SESSION)

    def test_stale_end_does_not_erase_new_session(self):
        self.seed({"@agent_session_id": OTHER_SESSION, "@agent_status": "working"})
        result = self.run_status("clear", payload={"session_id": SESSION})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.saved()["options"].get("@agent_session_id"), OTHER_SESSION)
        self.assertEqual(self.saved()["writes"], [])

    def test_opencode_watcher_must_own_pane(self):
        self.seed({"@agent_owner": "new-process", "@agent_session_id": "ses_new", "@agent_status": "working"})
        self.run_status("clear", "opencode", owner="old-process")
        self.assertEqual(self.saved()["writes"], [])

    def test_end_from_other_provider_does_not_clear_session(self):
        self.seed({"@agent_type": "opencode", "@agent_status": "ready", "@agent_owner": "new-process"})
        self.run_status("clear", "claude")
        self.assertEqual(self.saved()["writes"], [])

    def test_matching_end_clears_agent_fields(self):
        self.seed({"@agent_type": "claude", "@agent_session_id": SESSION, "@agent_status": "working"})
        self.run_status("clear", payload={"session_id": SESSION})
        self.assertEqual(self.saved()["options"], {})

    def test_codex_uses_explicit_type_without_transcript(self):
        self.seed({}, f"%8\tcodex\t/project\t{SESSION}\t100")
        self.run_status("working", "codex", {"session_id": SESSION, "cwd": "/project"})
        writes = self.saved()["writes"]
        self.assertTrue(writes)
        self.assertTrue(all(args[args.index("-t") + 1] == "%8" for args in writes))

    def test_codex_does_not_guess_between_two_unclaimed_panes(self):
        self.seed({}, "%8\tcodex\t/project\t\t100\n%9\tcodex\t/project\t\t200")
        result = self.run_status("working", "codex", {"session_id": SESSION, "cwd": "/project"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.saved()["writes"], [])

    def registry_calls(self):
        if not self.calls.exists():
            return []
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def test_stale_end_archives_old_identity_without_clearing_new_pane(self):
        self.seed({"@agent_type": "claude", "@agent_session_id": OTHER_SESSION, "@agent_status": "working"})
        self.run_status("clear", payload={"session_id": SESSION})
        calls = self.registry_calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["payload"]["session_id"], SESSION)
        self.assertEqual(self.saved()["writes"], [])

    def test_outside_codex_does_not_claim_unrelated_tmux_pane(self):
        self.env["TMUX"] = ""
        self.env["TMUX_PANE"] = ""
        self.seed({}, "%8\tcodex\t/project\t")
        self.run_status("working", "codex", {"session_id": SESSION, "cwd": "/project"})
        self.assertEqual(self.saved()["writes"], [])
        calls = self.registry_calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["args"][calls[0]["args"].index("--pane") + 1], "")

    def test_registry_registration_follows_pane_publication(self):
        self.run_status("working", payload={"session_id": SESSION})
        snapshot = self.registry_calls()[0]["pane_state"]
        self.assertEqual(snapshot.get("@agent_session_id"), SESSION)
        self.assertEqual(snapshot.get("@agent_type"), "claude")
        self.assertEqual(snapshot.get("@agent_status"), "working")

    def test_forwards_session_metadata_to_registry(self):
        payload = {"session_id": SESSION, "cwd": "/project", "transcript_path": "/logs/session.jsonl"}
        self.run_status("working", payload=payload)
        calls = self.registry_calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["payload"], payload)
        self.assertEqual(calls[0]["args"], ["session", "working", "--agent", "claude", "--pane", "%1", "--socket", "/tmp/tmux-test/socket", "--title", "Test conversation"])

    def test_registers_session_outside_tmux(self):
        self.env["TMUX_PANE"] = ""
        self.run_status("working", payload={"session_id": SESSION})
        calls = self.registry_calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["payload"]["session_id"], SESSION)
        self.assertIn("--pane", calls[0]["args"])
        self.assertEqual(calls[0]["args"][calls[0]["args"].index("--pane") + 1], "")
        self.assertEqual(self.saved()["writes"], [])

    def test_clear_reports_identity_before_clearing_pane(self):
        self.seed({"@agent_type": "opencode", "@agent_session_id": "ses_active", "@agent_owner": "process-1", "@agent_status": "working"})
        self.run_status("clear", "opencode", owner="process-1")
        calls = self.registry_calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["payload"]["session_id"], "ses_active")
        self.assertEqual(calls[0]["args"][:2], ["session", "clear"])
        self.assertEqual(self.saved()["options"], {})

    def test_focus_uses_existing_session_provider(self):
        self.seed({"@agent_type": "codex", "@agent_session_id": SESSION, "@agent_status": "done"})
        self.run_status("ready", "")
        calls = self.registry_calls()
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["payload"]["session_id"], SESSION)
        self.assertEqual(calls[0]["args"][3], "codex")

    def test_registry_failure_does_not_break_live_status(self):
        self.env["REGISTRY_FAIL"] = "1"
        result = self.run_status("working", payload={"session_id": SESSION})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.saved()["options"]["@agent_status"], "working")

    def test_absent_registry_does_not_break_live_status(self):
        self.env["TMUX_AGENT_RUNS"] = str(self.folder / "missing-runs")
        result = self.run_status("working", payload={"session_id": SESSION})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.saved()["options"]["@agent_status"], "working")

    def test_setup_installs_logs_helper(self):
        source = (ROOT / "setup.sh").read_text()
        start = source.index('mkdir -p "$local_bin"')
        stop = source.index("\ndone", start) + len("\ndone")
        local_bin = self.folder / "installed"
        script = 'repo_root=$1\nlocal_bin=$2\n' + source[start:stop]
        result = subprocess.run(["bash", "-c", script, "setup-test", str(ROOT), str(local_bin)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((local_bin / "tmux-agent-logs").resolve(), ROOT / "bin/tmux-agent-logs")


if __name__ == "__main__":
    unittest.main()
