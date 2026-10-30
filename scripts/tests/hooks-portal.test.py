#!/usr/bin/env python3
import importlib.util
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "hooks-portal.py"
spec = importlib.util.spec_from_file_location("portal", SCRIPT)
portal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portal)

NOW = 1793350000
ISO = "2026-10-30T10:00:00.000Z"
LATER = 1793500000


def success(command, event="PreToolUse", stdout="ctx", ms=10):
    return {"timestamp": ISO, "sessionId": "abcdefghij", "attachment": {"type": "hook_success", "hookEvent": event, "hookName": event + ":Bash", "command": command, "stdout": stdout, "durationMs": ms, "exitCode": 0}}


class Portal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.projects = self.dir / "projects" / "p"
        self.projects.mkdir(parents=True)
        self.transcript = self.projects / "s.jsonl"
        self.wrapper = self.dir / "runs.jsonl"
        self.settings = self.dir / "settings.json"
        self.settings.write_text(json.dumps({"hooks": {"Stop": [{"hooks": [
            {"command": "$HOME/.claude/hooks/hook-run Stop quiet $HOME/.claude/hooks/quiet.sh"},
            {"command": "$HOME/.claude/hooks/hook-run Stop never $HOME/.claude/hooks/never.sh"},
        ]}]}}))
        self.db = sqlite3.connect(":memory:")
        self.db.executescript(portal.SCHEMA)

    def write(self, path, entries, mode="a"):
        with open(path, mode) as out:
            for entry in entries:
                out.write(json.dumps(entry) + "\n")

    def index(self):
        portal.index(self.db, self.dir / "projects", self.wrapper)

    def count(self, where="1=1"):
        return self.db.execute(f"select count(*) from runs where {where}").fetchone()[0]

    def test_names(self):
        self.assertEqual(portal.hook_name('python3 "$HOME/.claude/hooks/guard.py"'), "guard")
        self.assertEqual(portal.hook_name('bash "${CLAUDE_PLUGIN_ROOT}/hooks/a.sh" "${CLAUDE_PLUGIN_ROOT}/hooks/b.py"'), "b")
        self.assertEqual(portal.hook_name("$HOME/.claude/hooks/hook-run Stop x $HOME/.claude/hooks/y.sh"), "x")

    def test_index_is_incremental(self):
        self.write(self.transcript, [success("/h/a.sh")])
        self.index()
        self.index()
        self.assertEqual(self.count(), 1)
        self.write(self.transcript, [success("/h/a.sh")])
        self.index()
        self.assertEqual(self.count(), 2)

    def test_partial_line_waits(self):
        self.write(self.transcript, [success("/h/a.sh")])
        with open(self.transcript, "a") as out:
            out.write('{"timestamp": "' + ISO)
        self.index()
        self.assertEqual(self.count(), 1)
        with open(self.transcript, "a") as out:
            out.write('", "attachment": {"type": "hook_success", "hookEvent": "PreToolUse", "command": "/h/b.sh"}}\n')
        self.index()
        self.assertEqual(self.count(), 2)

    def test_garbage_is_skipped(self):
        self.transcript.write_text('not json with hook\n["hook"]\n')
        self.wrapper.write_text('not json\n{"hook":"x"}\n')
        self.index()
        self.assertEqual(self.count(), 0)

    def test_stop_summary_and_block(self):
        self.write(self.transcript, [
            {"timestamp": ISO, "subtype": "stop_hook_summary", "hookInfos": [{"command": "/h/stop.sh", "durationMs": 5}, {"command": "callback"}]},
            {"timestamp": ISO, "attachment": {"type": "hook_blocking_error", "hookEvent": "Stop", "blockingError": {"command": "/h/stop.sh", "blockingError": "nope"}}},
        ])
        self.index()
        self.assertEqual(self.count("hook='stop' and kind='run'"), 1)
        self.assertEqual(self.count("hook='stop' and kind='block'"), 1)
        self.assertEqual(self.count("hook='callback'"), 0)

    def test_wrapper_replaces_transcript_from_its_start(self):
        self.write(self.transcript, [success("/h/a.sh")])
        self.write(self.wrapper, [
            {"at": NOW, "event": "Stop", "hook": "a", "ms": 7, "exit": 0, "bytes": 3, "blocked": False},
            {"at": NOW, "event": "Stop", "hook": "a", "ms": 9, "exit": 2, "bytes": 0, "blocked": True},
        ])
        self.index()
        runs, _ = portal.load_runs(self.db, 0)
        s = portal.summarize_hook(runs["a"])
        self.assertEqual((s["runs"], s["blocks"], s["errors"]), (2, 1, 0))
        self.assertTrue(s["wrapper"])

    def test_forked_history_counts_once(self):
        entry = {**success("/h/a.sh"), "uuid": "same"}
        self.write(self.transcript, [entry])
        self.write(self.projects / "fork.jsonl", [entry])
        self.index()
        self.assertEqual(self.count(), 1)

    def test_pretooluse_refusal_from_tool_result(self):
        text = 'PreToolUse:Bash hook error: [[ ! -f "$HOME/g.py" ] || python3 "$HOME/g.py"]: refused'
        self.write(self.transcript, [{"timestamp": ISO, "type": "user", "message": {"content": [{"type": "tool_result", "content": text}]}}])
        self.index()
        self.assertEqual(self.db.execute("select hook, kind, excerpt from runs").fetchall(), [("g", "block", "refused")])

    def test_silent_needs_a_week_of_wrapper_data(self):
        self.write(self.wrapper, [
            {"at": NOW - 8 * 86400, "hook": "quiet", "ms": 1, "exit": 0, "bytes": 0, "blocked": False},
            {"at": NOW, "hook": "quiet", "ms": 1, "exit": 0, "bytes": 0, "blocked": False},
        ])
        self.index()
        page = portal.build(self.db, self.dir / "portal", self.settings, self.dir / "none.log", now=NOW + 60).read_text()
        self.assertIn("молчит", page)

    def test_wrapper_failure_counts_as_error(self):
        self.write(self.wrapper, [{"at": NOW, "hook": "a", "ms": 1, "exit": 1, "bytes": 0, "blocked": False}])
        self.index()
        runs, _ = portal.load_runs(self.db, 0)
        self.assertEqual(portal.summarize_hook(runs["a"])["errors"], 1)

    def test_portal_pages(self):
        self.write(self.wrapper, [{"at": NOW, "hook": "quiet", "ms": 4, "exit": 0, "bytes": 0, "blocked": False}])
        self.write(self.transcript, [
            {"timestamp": ISO, "attachment": {"type": "hook_blocking_error", "hookEvent": "Stop", "blockingError": {"command": "/h/evil.sh", "blockingError": "<img src=x>"}}},
        ])
        self.index()
        out = self.dir / "portal"
        page = portal.build(self.db, out, self.settings, self.dir / "none.log", now=NOW + 60).read_text()
        self.assertIn("quiet", page)
        self.assertIn("never", page)
        self.assertIn("мало данных", page)
        self.assertIn("нет данных", page)
        self.assertNotIn("{kpis}", page)
        evil = (out / "hook-evil.html").read_text()
        self.assertIn("&lt;img src=x&gt;", evil)
        self.assertNotIn("<img", evil)
        self.assertTrue((out / "delegation-guard.html").exists())
        self.assertIn('href="index.html"', (out / "hook-quiet.html").read_text())


if __name__ == "__main__":
    unittest.main()
