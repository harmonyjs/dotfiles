# Dotfiles Repository

Personal macOS terminal environment: tmux + Alacritty with Catppuccin Latte theme, vim-style navigation, and GNU Stow symlink management.

## Documentation

- **[README.md](README.md)** - Complete guide: installation, usage, troubleshooting
- **[AGENTS.md](AGENTS.md)** - AI agent instructions and workflow scenarios
- **[docs/TMUX.md](docs/TMUX.md)** - Tmux keybindings and commands reference
- **[docs/ALACRITTY.md](docs/ALACRITTY.md)** - Alacritty-tmux integration details

## Key Concepts

- **GNU Stow** manages symlinks from repo to `~` directory
- **GNU Stow requires `-t ~`** — without it, stow targets the parent directory of the repo, not `$HOME`. The canonical invocation is `stow --restow --no-folding -t ~ .`. The `scripts/lib/symlinks.sh:run_stow()` function is the source of truth for stow flags.
- **`.stow-local-ignore`** defines files excluded from symlinking
- **`--no-folding`** flag required for `.claude` directory
- **`./scripts/bootstrap`** (or `just bootstrap <git-url>`) — entrypoint for a brand-new Mac. Walks from blank macOS install to fully configured environment, with one manual gate for 1Password desktop. The gate is **conditional** (skipped when SSH already authenticates). Supports `--dry-run` (preview, change nothing) and `-y/--yes` (unattended — never block on a prompt; human/sudo-gated steps skip with a note). See [AGENTS.md](AGENTS.md) Scenario 4.
- **`./scripts/init`** (or `just init`) — idempotent setup: brew bundle, submodules, stow, tmux plugins. Safe to re-run anytime.
- **`./scripts/post-install`** (or `just post-install`) — one-shot system tweaks: TouchID for sudo via `/etc/pam.d/sudo_local` and SSH `known_hosts` for github.com. **Sudo-aware**: skips the root-only TouchID write (with a note) when sudo isn't available, e.g. under `bootstrap -y`. Does not touch the hostname.
- **`./scripts/check`** (or `just check`) validates entire setup. Its "Stow dry run" section runs `stow --restow --no-folding --simulate -v` against `~` and goes red on a conflict (stow is all-or-nothing, so one stray real file at a linked path, a `.pyc` or a stale directory copy, blocks delivery of every new file) and on any file not linked yet (a `LINK` with no matching `UNLINK`, meaning the repo gained it after the last stow). The "Symlinks" section audits a fixed list and sees neither. `init` stows on every run for the same reason, rather than skipping when the shell links already exist. `just test-stow-check` runs its tests.
- **`scripts/lib/git.sh`** — `ssh_ready` (1Password agent holds a key **and** GitHub authenticates it; side-effect-free probe) and `ensure_ssh_remote` (converges `origin` HTTPS → SSH, but only once `ssh_ready` passes; never downgrades). `init` runs `ensure_ssh_remote` every time, so the remote **self-heals** to SSH after you unlock 1Password; `check` reports a "Git remote" section; `bootstrap`'s manual 1Password gate is skipped whenever `ssh_ready` already passes.
- **`.claude/`** is a git submodule with Claude Code configs
- **Shared global instructions:** `.claude/CLAUDE.md` is the single submodule source for both Claude Code and Codex; `.agents/INSTRUCTIONS.md` and `.codex/AGENTS.md` are relative repository aliases. `just instructions` installs only these links and their layout guide/checker via Stow; `just check-instructions` verifies them. See [.agents/instruction-layout/README.md](.agents/instruction-layout/README.md). Keep edits in the resolved Git-backed source and preserve home symlinks.
- **`commit-pr-guide` hook** (`.claude/hooks/commit-pr-guide.sh`) injects Andrey's commit / PR / review-comment writing conventions (read verbatim from `.claude/knowledge/git-writing/`: `_common.md` + one per-surface file) at authoring time: on `UserPromptSubmit` when the prompt signals commit/PR/review intent, and on `PreToolUse(Bash)` for `git commit` / `gh pr create|edit|merge` / review commands. The PreToolUse path also **denies** commits/PRs carrying `Co-Authored-By` / AI attribution — it scans the command string plus any `--body-file`/`-F` file and amended message, matching AI-specific patterns only (a human `Co-Authored-By` and a mere mention of the trailer both pass). Guides resolve relative to the hook (not `$HOME`), so a **`stow --restow` is required after adding or renaming guide/hook files** for the runtime `~/.claude/` symlinks to pick them up. A per-session-per-domain TTL marker dedups injection while the guard always runs. `just test-commit-guide` runs its tests.
- **`stop-ask-user` hook** (`.claude/hooks/stop-ask-user.sh`) is a `Stop` hook that turns a silent end-of-turn into an explicit hand-off: when the agent finishes a turn in which it called at least one tool, the hook returns `decision: block` with an instruction to close the turn via `AskUserQuestion` — self-contained summary inside `question`, 2-4 concrete ways to continue as `options`, one of them ending the work. It stays silent for pure conversational turns (no tool calls), when the last tool was already `AskUserQuestion`/`ExitPlanMode`, for subagents, and while `background_tasks` are in flight. **Loop safety is stateless**: Claude Code sets `stop_hook_active` while a turn is already continuing because of a Stop hook, so exactly one block lands per user prompt — no state files to go stale. Escape hatch for non-interactive runs (`claude -p` has no `AskUserQuestion`): `CLAUDE_NO_STOP_ASK=1` or `touch ~/.claude/.no-stop-ask`. **Wire-format gotcha, verified against the 2.1.233 binary and NOT what the published Stop docs say**: a command hook blocks with a *top-level* `{"decision":"block","reason":"..."}`; for `Stop`, `hookSpecificOutput` maps only to `additionalContext`, so a decision placed there is silently ignored. `just test-stop-ask` runs its tests.
- **`zsh-colon-modifier-guard` hook** (`.claude/hooks/zsh-colon-modifier-guard.py`) is a `PreToolUse(Bash)` refusal for `$name:X` where zsh, the Bash tool's shell, would apply a history modifier: `git show origin/$b:src/x` runs `$b` through `:s` with `r` as delimiter and silently drops the path. It fires only on the letters zsh 5.9 actually applies (`a c e h l q r s t u A P Q &`, optionally prefixed by `g w f`, plus `F`/`W` with a delimiter), so `$host:port`, `$PWD:/app` and `$host:22` pass, and only in expanding text: single quotes, `$'...'`, comments, `\$` and quoted heredoc bodies are skipped, while double quotes, `$(...)`, backticks, here-strings and unquoted heredoc bodies are checked. The refusal prints the braced rewrite (`${b}:src/x`); a wanted modifier goes inside the braces (`${f:t}`). Bypass: `ZSH_COLON_OK=1`. `just test-zsh-colon` runs its tests.
- **`.private/`** is a git submodule with identity-bearing and machine-specific configs (see Repository Structure below for current scope)
- **Memory is NOT managed by stow.** `projects` is in `.stow-local-ignore`. Claude Code auto-memory drifts the wrong way for stow — files are *born* in `~` (runtime writes), not in the repo — so `scripts/lib/memory.sh:link_memory()` owns it instead: each `~/.claude/projects/<id>/memory` is a single **directory symlink** into the `.claude` submodule, so runtime memory writes land directly in the repo working tree. `init` runs `link_memory` (self-healing), `check` audits it via `check_memory`, and a fail-safe **SessionStart hook** (`.claude/hooks/session-start-memory.sh`) makes a project repo-backed before its first memory write. `just memory` runs the linker; `just test-memory` runs its unit tests. Durability target is *capture in the working tree* — committing memory is manual / `oneiron`-owned, never automatic.
- **Memory gotchas (baked into the linker, learned the hard way):**
  - A memory dir must be **flat** (atom `*.md` + `MEMORY.md`). `link_memory_id` refuses any dir containing a real subdirectory — partially migrating around it would move the loose files yet fail to `rmdir`, leaving a half-linked drift. Move runtime/scratch subdirs out and re-run.
  - The `oneiron` skill's audit/scratch tree lives as a **sibling** of the store — `~/.claude/projects/<id>/.oneiron/`, never inside `memory/` — precisely so it stays out of the versioned repo.
  - `memory_project_id` must reproduce Claude Code's own project-id encoding exactly, or the hook links a sibling id Claude never writes to while the real dir stays unlinked drift. The rule, read from the `claude` binary: every UTF-16 code unit outside `[a-zA-Z0-9]` becomes `-` (spaces, `~`, `_` and non-ASCII included, not just `/` and `.`); an id longer than 200 is cut to 200 and suffixed `-<base36 of abs(Java-style 31-hash)>`. It is implemented in `perl` because bash cannot count UTF-16 units. Re-verify against a new Claude Code release by comparing ids with transcript `cwd`s.
  - Any caller that sources `scripts/lib/common.sh` outside a script file (e.g. `bash -c 'source …'`, the `memory` recipe, the hook) **must pass `DOTFILES_DIR` explicitly** — `BASH_SOURCE[1]` is empty there and the auto-derivation yields the wrong parent (`~/GitHub` instead of `~/GitHub/dotfiles`), silently linking memory into a stray tree. `common.sh` now honors a pre-set `DOTFILES_DIR`.

## Repository Structure

**Public tree (this repo):**
- `.config/tmux/tmux.conf` - tmux config (prefix: `Ctrl+Space`)
- `.config/alacritty/alacritty.toml` - terminal with auto-start tmux session "main"
- `.zshenv` - environment variables and PATH (loaded always)
- `.zprofile` - login shell config (intentionally empty)
- `.zshrc` - interactive shell config (sources `.zsh_aliases` and `.zshrc.local`)
- `.zsh_aliases` - command aliases
- `Brewfile` - declarative Homebrew package manifest (CLIs, fonts, headless utilities only)
- `scripts/bootstrap`, `scripts/init`, `scripts/post-install`, `scripts/check`, `scripts/update`, `scripts/dry-run` - lifecycle scripts (sourced from `scripts/lib/*.sh`)

**`.private/` submodule (identity-bearing, machine-specific):**
- `.config/git/config`, `.config/git/allowed_signers` - git identity + SSH signing trust
- `.ssh/config`, `.ssh/*.pub` - SSH client config and public keys for this user
- `.config/1Password/ssh/agent.toml` - 1Password SSH agent config (serves keys from the `ssh` vault; versioned so a fresh machine doesn't get 1Password's empty `vault = "Personal"` default)
- `.zshrc.local`, `.zsh_history` - per-machine shell state
- `.codex/config.toml`, `.gemini/settings.json` - AI assistant per-tool configs
- `.config/imgcluster/.env`, `.config/tg-exporter/.env`, `.config/kcat.conf` - service-specific env/configs
- `.agents/skills/` - the personal skill catalog, reached through the `~/.agents/skills` directory symlink rather than stow (see Stow exceptions below); private because the skills name clients, internal projects and this machine
- `.local/bin/{simreap,memwatch,janitor}`, `Library/LaunchAgents/dev.vavilov.*.plist`, `.local/share/clickhouse-ci-config/` - this machine's maintenance agents and the config they install

**Public-vs-private rule:** anything that contains hostnames, public keys, email addresses, identity, credentials, or paths meaningful only to Andrey's specific machines belongs in `.private/`. The public tree is for curated tool choices and universal patterns that anyone can fork.

## ZSH Configuration Rules

ZSH files have strict separation of concerns. Follow these rules when modifying shell configuration:

| What to add | Where to put it |
|-------------|-----------------|
| PATH modifications | `.zshenv` |
| Environment variables (`export VAR=value`) | `.zshenv` |
| Prompt configuration | `.zshrc` |
| Completion setup | `.zshrc` |
| Key bindings | `.zshrc` |
| Aliases and functions | `.zsh_aliases` |
| Interactive utilities (fzf, zoxide) | `.zshrc` |
| Machine-specific settings | `.zshrc.local` (not version controlled) |

**Loading order:** `.zshenv` → `.zprofile` → `.zshrc`

**Critical rules:**
- NEVER add PATH or environment variables to `.zshrc` — they won't be available in scripts/cron
- NEVER add interactive features to `.zshenv` — it runs for non-interactive shells too
- Keep `.zprofile` empty — all PATH setup is in `.zshenv` for universal availability
- Use `.zshrc.local` for machine-specific environment variables (like `NODE_EXTRA_CA_CERTS`)

## Development Principles

**No broken states** — Never commit changes that leave the setup non-functional. If something doesn't work via Homebrew, find an alternative and automate it. The only sanctioned manual gate is in `scripts/bootstrap` where the user installs 1Password desktop — and that gate is interactive, in-band, and clearly explained to the user; it is not a "go read the docs and figure it out" comment.

**User-first thinking** — Every decision is made from the perspective of someone cloning this repo on a fresh machine. They shouldn't read code comments or debug why something didn't install.

**Automation over documentation** — If an action can be automated and the policy permits it, it must be automated. The cask-vs-dmg policy (see below) is an explicit exception: desktop GUI apps are intentionally installed manually because that's the curated update path, not because automation is infeasible.

**Curated tool sourcing** — Homebrew is for CLIs, fonts, and headless system utilities. Desktop GUI apps (editors/IDEs, messengers, productivity, browsers, 1Password desktop, office suites) are installed from their official `.dmg`. When adding a new package: if it ships a GUI app you'd otherwise launch from Spotlight, do not add it as `cask "<name>"` to the Brewfile — note it in README/AGENTS or leave it implicit.

**Attention to details** — Details matter: correct installation paths, clean directory structure, no warnings. Quality is built from details.

## AI Agent Guidelines

**Before changes:**
1. Verify all three repos (dotfiles, `.claude/`, `.private/`) are on `main`, up to date with remote, and working tree clean — report status before proceeding
2. Read [AGENTS.md](AGENTS.md) for detailed scenarios
3. Run `just check` to check current state
4. Create backups before modifying configs

**After changes:**
1. Run `just check` - all checks must pass
2. Update docs if keybindings or behavior changed
3. Preserve Catppuccin Latte theme (critical requirement)

**Submodule hygiene (`.claude/`, `.private/`):**
- Before committing or pushing, ensure each submodule is on `main` and up to date with its remote (`git -C <submodule> fetch && git -C <submodule> status`)
- If a submodule is in detached HEAD — checkout `main` and pull before proceeding
- After updating submodule content, commit the new ref in the parent repo and push both

**Critical rules:**
- Maintain macOS + Homebrew compatibility
- Always use stow for symlink management
- Create backups before config modifications
- NEVER create symlinks manually, stow has to manage them
- **Stow exceptions (runtime-written trees):** stow is the source of truth for static config, which it links *from* the repo *into* `~`. Two trees run the other way — they are written at runtime and have to land in the working tree as they are written — and each is owned by a single directory symlink instead. `scripts/lib/memory.sh:link_memory` owns `~/.claude/projects/*/memory`; `scripts/lib/skills.sh:link_skills` owns `~/.agents/skills`, which points at `.private/.agents/skills` and is why `.agents` is in `.private/.stow-local-ignore`. Both run from `init` and are audited by `check` (`check_memory`, `check_skills`). `link_skills` refuses rather than overwrites when a real directory already sits at the alias path, because that means two catalogs exist. Stow would also have mangled the skill catalog outright: `.stow-local-ignore` strips every `README.md` but one, and 58 of them are reference material inside the `cloudflare` and `turnstile-spin` skills. `.agents/skills/synced` is gitignored, being Claude's own managed sync directory with its own lifecycle. These two are the only sanctioned places symlinks are not created by stow; a third needs the same justification, not just convenience.
