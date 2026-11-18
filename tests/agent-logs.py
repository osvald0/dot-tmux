import contextlib
import io
import json
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
logs = runpy.run_path(str(ROOT / "bin/tmux-agent-logs"))


class AgentLogsTests(unittest.TestCase):
    def test_keeps_following_after_empty_tool_results(self):
        records = [
            {"type": "user", "message": {"content": [{"type": "tool_result", "content": ""}]}},
            {"type": "user", "message": {"content": [{"type": "tool_result", "content": []}]}},
            {"type": "response_item", "payload": {"type": "function_call_output", "output": ""}},
            {"type": "response_item", "payload": {"type": "custom_tool_call_output", "output": ""}},
        ]
        for record in records:
            with self.subTest(record=record), tempfile.TemporaryDirectory() as folder:
                transcript = Path(folder) / "transcript.jsonl"
                transcript.write_text(json.dumps(record) + "\n")
                viewer = logs["Viewer"]("test-session", str(transcript), None)
                output = io.StringIO()

                with contextlib.redirect_stdout(output):
                    logs["load_sources"](viewer)
                    with transcript.open("a") as file:
                        file.write(json.dumps(record) + "\n")
                        file.write(json.dumps({
                            "type": "assistant",
                            "message": {"content": [{"type": "text", "text": "Still following"}]},
                        }) + "\n")

                    logs["poll"](viewer)
                    logs["redraw"](viewer)

                self.assertEqual(output.getvalue().count("Still following"), 2)

    def test_empty_failed_tool_result_still_shows_error(self):
        viewer = logs["Viewer"]("test-session", None, None)
        source = logs["Source"]("unused", "main", "main", "")
        record = {
            "type": "user",
            "message": {"content": [{"type": "tool_result", "content": "", "is_error": True}]},
        }
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            logs["ingest_transcript"](viewer, source, [json.dumps(record)])

        self.assertIn("error", output.getvalue())


if __name__ == "__main__":
    unittest.main()
