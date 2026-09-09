# Shared global instructions

The single maintained source is `.claude/CLAUDE.md` in the dotfiles checkout's
existing `.claude` Git submodule. Personal instructions stay in that submodule;
the parent repository contains only the generic layout and installation tooling.

| Installed path | Repository entry |
| --- | --- |
| `~/.claude/CLAUDE.md` | `.claude/CLAUDE.md` (regular source file) |
| `~/.codex/AGENTS.md` | `.codex/AGENTS.md` → `../.claude/CLAUDE.md` |
| `~/.agents/INSTRUCTIONS.md` | `.agents/INSTRUCTIONS.md` → `../.claude/CLAUDE.md` |

GNU Stow creates relative links from home to these repository entries. All three
names resolve to the same file. The checker and this guide are also linked from
the repository into `~/.agents/instruction-layout/`.

## Restore and verify

From the dotfiles checkout, after initializing its `.claude` submodule:

```bash
just instructions --dry-run  # Stow simulation, no writes
just instructions           # Install only the five instruction-related links
just check-instructions     # Read-only, independent of other environment checks
just check                  # Full environment check, including instructions
```

`scripts/init` also runs the dedicated installer even when the shell dotfiles
are already linked. The installer uses Stow's normal ignore policy plus an exact
allowlist of instruction paths; unrelated shell, skills and memory conflicts do
not enter this operation. A conflicting regular file or foreign link causes a
failed preflight. It is never adopted, overwritten or deleted automatically.
Back up and reconcile that file before removing the conflict and retrying.

For an isolated installation check, use `scripts/instructions --target <empty-dir>`
and `python3 .agents/instruction-layout/check.py --home <empty-dir>`.

## Editing and durability

Resolve an instruction path to its real source before editing. An editor that
atomically replaces a home alias with a regular file can detach it from dotfiles;
the checker detects this. Preserve all three aliases and keep no independent
global `AGENTS.override.md` that shadows the Codex source.

An edit through the resolved source appears in `git -C .claude diff -- CLAUDE.md`.
To reproduce it from a fresh clone, the submodule change and the parent repository's
updated submodule pointer must both be committed and published with the user's
authorization. Local working-tree edits alone do not update a remote clone.

Existing sessions can retain loaded instructions; fresh sessions read the links.
This layout targets Claude Code and Codex, not Claude Cowork. Project instructions
and native memory writers remain independent. The separate shared skill and QMD
setup referenced by the instructions has its own installation requirements;
this installer restores only the global instruction files and their layout tools.

Historical migration backups stay local under
`~/.agents/instruction-layout/migrations/`; they are not active sources or part of
the repository installation.

References: [Claude Code memory](https://code.claude.com/docs/en/memory),
[Codex global instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
