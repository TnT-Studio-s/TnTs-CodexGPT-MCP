import json
import tempfile
import time
import unittest
from pathlib import Path

from codex_buddy import CodexTelemetry, format_window, prompt_cost, short_model


class LinuxTelemetryTests(unittest.TestCase):
    def write_session(self, root: Path) -> Path:
        session_path = root / "sessions" / "2026" / "07" / "22" / "session.jsonl"
        session_path.parent.mkdir(parents=True)
        now = time.time()
        entries = [
            {"timestamp": "2026-07-22T12:00:00Z", "type": "session_meta", "payload": {"id": "abc", "cwd": "/work/demo"}},
            {"timestamp": now, "type": "turn_context", "payload": {"model": "gpt-5.4", "turn_id": "turn-1"}},
            {"timestamp": now, "type": "response_item", "payload": {"type": "message", "role": "user"}},
            {"timestamp": now, "type": "response_item", "payload": {"type": "custom_tool_call", "name": "shell_command"}},
            {"timestamp": now, "type": "event_msg", "payload": {"type": "token_count", "info": {
                "total_token_usage": {"total_tokens": 4200, "input_tokens": 3000, "output_tokens": 1200, "cached_input_tokens": 500},
                "last_token_usage": {"total_tokens": 4200, "input_tokens": 3000, "output_tokens": 1200, "cached_input_tokens": 500},
                "model_context_window": 10000,
            }, "rate_limits": {"primary": {"used_percent": 25, "window_minutes": 300}}}},
            {"timestamp": now, "type": "event_msg", "payload": {"type": "task_complete", "duration_ms": 1500}},
        ]
        session_path.write_text("\n".join(json.dumps(entry) for entry in entries) + "\n", encoding="utf-8")
        return session_path

    def test_reads_linux_codex_session_stream(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_session(root)
            snapshot = CodexTelemetry(root).snapshot()
            session = snapshot["session"]
            self.assertIsNotNone(session)
            self.assertEqual(session.session_id, "abc")
            self.assertEqual(session.active_model, "gpt-5.4")
            self.assertEqual(session.tool_calls, 1)
            self.assertEqual(session.last_tokens, 4200)
            self.assertEqual(session.context_percent, 30.0)
            self.assertEqual(session.primary_limit["used_percent"], 25)
            self.assertEqual(session.task_count, 1)

    def test_cost_and_display_helpers_match_linux_contract(self):
        cost = prompt_cost({"input_tokens": 1000, "cached_input_tokens": 200, "output_tokens": 100}, "gpt-5.4")
        self.assertEqual(cost, 3550.0)
        self.assertEqual(short_model("foo-gpt-5.4-mini-bar"), "GPT-5.4 Mini")
        self.assertEqual(format_window(10080), "week")

    def test_malformed_lines_do_not_break_refresh(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            session_path = self.write_session(root)
            session_path.write_text("not json\n" + session_path.read_text(encoding="utf-8"), encoding="utf-8")
            self.assertIsNotNone(CodexTelemetry(root).snapshot()["session"])


if __name__ == "__main__":
    unittest.main()
