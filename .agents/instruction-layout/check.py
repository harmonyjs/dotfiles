#!/usr/bin/env python3
"""Read-only verification of the shared, repository-backed instructions."""
import argparse
import os
from pathlib import Path
import sys


def check(home: Path, repo: Path) -> list[str]:
    source = repo / ".claude/CLAUDE.md"
    errors = []
    if source.is_symlink() or not source.is_file():
        return [f"Expected regular source file in the .claude submodule: {source}"]

    for relative in (
        ".claude/CLAUDE.md",
        ".codex/AGENTS.md",
        ".agents/INSTRUCTIONS.md",
        ".agents/instruction-layout/check.py",
        ".agents/instruction-layout/README.md",
    ):
        alias = home / relative
        expected = repo / relative
        if not alias.is_symlink():
            errors.append(f"Expected symlink: {alias}")
        elif os.path.isabs(os.readlink(alias)):
            errors.append(f"Expected relative symlink: {alias}")
        else:
            try:
                if not alias.samefile(expected):
                    errors.append(f"Wrong target: {alias}; expected {expected}")
            except (OSError, RuntimeError):
                errors.append(f"Broken or cyclic symlink: {alias}")

    for relative in (".codex/AGENTS.md", ".agents/INSTRUCTIONS.md"):
        alias = repo / relative
        if not alias.is_symlink() or os.readlink(alias) != "../.claude/CLAUDE.md":
            errors.append(f"Expected repository alias to ../.claude/CLAUDE.md: {alias}")

    override = home / ".codex/AGENTS.override.md"
    if override.exists() or override.is_symlink():
        errors.append(f"Global Codex override shadows the shared instructions: {override}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home(), help="Target home to verify")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    errors = check(args.home.resolve(), repo)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    source = repo / ".claude/CLAUDE.md"
    print(f"OK: Claude Code, Codex and .agents read {source} ({source.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
