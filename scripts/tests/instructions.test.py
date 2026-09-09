#!/usr/bin/env python3
"""Exercise real Stow in isolated homes; never change the user's environment."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class InstructionLayoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-instructions-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "test home"
        self.home.mkdir()

    def run_command(self, command, expected=0):
        result = subprocess.run(command, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def install(self, *args, expected=0):
        return self.run_command(
            [str(REPO / "scripts/instructions"), "--target", str(self.home), *args], expected
        )

    def check(self, expected=0):
        return self.run_command(
            ["python3", str(REPO / ".agents/instruction-layout/check.py"), "--home", str(self.home)],
            expected,
        )

    def test_fresh_install_and_idempotency(self):
        self.install("--dry-run")
        self.assertEqual(list(self.home.iterdir()), [])
        self.install()
        self.check()
        aliases = [p for p in self.home.rglob("*") if p.is_symlink()]
        self.assertEqual(len(aliases), 5)
        before = {str(p): (p.readlink(), p.lstat().st_ino) for p in aliases}
        self.install()
        self.assertEqual(before, {str(p): (p.readlink(), p.lstat().st_ino) for p in aliases})

    def test_unrelated_conflicts_are_untouched(self):
        (self.home / ".zshrc").write_text("private shell config\n")
        (self.home / ".claude").mkdir()
        (self.home / ".claude/skills").write_text("unrelated conflict\n")
        self.install()
        self.assertEqual((self.home / ".zshrc").read_text(), "private shell config\n")
        self.assertEqual((self.home / ".claude/skills").read_text(), "unrelated conflict\n")

    def test_regular_file_conflict_aborts_before_mutation(self):
        (self.home / ".claude").mkdir()
        conflict = self.home / ".claude/CLAUDE.md"
        conflict.write_text("instructions to preserve\n")
        self.install(expected=1)
        self.assertEqual(conflict.read_text(), "instructions to preserve\n")
        self.assertFalse(conflict.is_symlink())
        self.assertFalse((self.home / ".agents").exists())
        self.assertFalse((self.home / ".codex").exists())

    def test_checker_rejects_detached_copy(self):
        self.install()
        alias = self.home / ".codex/AGENTS.md"
        content = alias.read_bytes()
        alias.unlink()
        alias.write_bytes(content)
        self.check(expected=1)

    def test_checker_rejects_override(self):
        self.install()
        (self.home / ".codex/AGENTS.override.md").write_text("override\n")
        self.check(expected=1)

    def test_full_stow_installs_only_intended_document_exceptions(self):
        # Minimal fresh-checkout fixture verifies the normal root Stow route too.
        package = Path(self.temp.name) / "dotfiles checkout"
        package.mkdir()
        for relative in (
            ".stow-local-ignore", ".claude/CLAUDE.md", ".codex/AGENTS.md",
            ".agents/INSTRUCTIONS.md", ".agents/instruction-layout/check.py",
            ".agents/instruction-layout/README.md",
        ):
            destination = package / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO / relative, destination, follow_symlinks=False)
        for relative in ("README.md", "AGENTS.md", "CLAUDE.md", ".claude/README.md", ".claude/AGENTS.md"):
            (package / relative).write_text("repository-only guidance\n")
        self.run_command(["stow", "-v", "-t", str(self.home), "--no-folding", "-d", str(package), "."])
        self.run_command(["python3", str(package / ".agents/instruction-layout/check.py"), "--home", str(self.home)])
        for relative in ("README.md", "AGENTS.md", "CLAUDE.md", ".claude/README.md", ".claude/AGENTS.md"):
            self.assertFalse((self.home / relative).exists(), relative)


if __name__ == "__main__":
    unittest.main(verbosity=2)
