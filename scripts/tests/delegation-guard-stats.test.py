#!/usr/bin/env python3
import importlib.util
import json
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "delegation-guard-stats.py"
spec = importlib.util.spec_from_file_location("stats", SCRIPT)
stats = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stats)

NOW = int(datetime(2026, 10, 30, 12).timestamp())
EVENTS = [
    {"at": NOW, "delegates": True, "quote": "legacy", "ms": 5000},
    {"at": NOW, "delegates": False, "quote": "", "ms": 7000},
    {"at": NOW, "error": "boom"},
    {"at": NOW, "outcome": "not_candidate", "session": "a"},
    {"at": NOW, "outcome": "not_candidate", "session": "a"},
    {"at": NOW, "outcome": "cleared", "session": "a", "ms": 4000, "tokens": 1000},
    {"at": NOW, "outcome": "blocked", "session": "a", "ms": 6000, "tokens": 2000, "quote": "<script>alert(1)</script>"},
    {"at": NOW, "outcome": "after_block", "session": "a", "tools_after": 2},
    {"at": NOW, "outcome": "after_block", "session": "b", "tools_after": 0},
]


class Stats(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.log = Path(self.tmp.name) / "log"
        lines = [json.dumps(e) for e in EVENTS] + ["not json", json.dumps({"no": "timestamp"})]
        self.log.write_text("\n".join(lines))

    def test_load_maps_legacy_lines_and_skips_garbage(self):
        events = stats.load(self.log)
        self.assertEqual(len(events), len(EVENTS))
        self.assertEqual([e["outcome"] for e in events[:3]], ["blocked", "cleared", "error"])

    def test_summary(self):
        s = stats.summarize(stats.load(self.log))
        self.assertEqual((s["checks"], s["blocked"], s["errors"]), (4, 2, 1))
        self.assertEqual(s["stops"], 4)
        self.assertEqual(s["candidate_share"], 0.5)
        self.assertEqual((s["acted"], s["after"]), (1, 2))
        self.assertEqual(s["median_ms"], 5500)
        self.assertEqual(s["tokens"], 3000)

    def test_page_escapes_quotes(self):
        page = stats.render(stats.load(self.log), datetime(2026, 10, 30).date())
        self.assertNotIn("<script>alert", page)
        self.assertIn("&lt;script&gt;alert", page)
        self.assertNotIn("{kpis}", page)

    def test_missing_log_renders_empty_page(self):
        page = stats.render(stats.load(Path(self.tmp.name) / "nope"), datetime(2026, 10, 30).date())
        self.assertIn("Данных пока нет", page)
        self.assertIn("Блоков пока нет", page)


if __name__ == "__main__":
    unittest.main()
