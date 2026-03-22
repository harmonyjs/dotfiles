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
- **`./scripts/check`** (or `just check`) validates entire setup
- **`.claude/`** is a git submodule with Claude Code configs

## Repository Structure

- `.config/tmux/tmux.conf` - tmux config (prefix: `Ctrl+Space`)
- `.config/alacritty/alacritty.toml` - terminal with auto-start tmux session "main"
- `.config/git/config` - git user config (in `.private` submodule)
- `.zshenv` - environment variables and PATH (loaded always)
- `.zprofile` - login shell config (intentionally empty)
- `.zshrc` - interactive shell config (sources `.zsh_aliases` and `.zshrc.local`)
- `.zsh_aliases` - command aliases

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

**No broken states** — Never commit changes that leave the setup non-functional. If something doesn't work via Homebrew, find an alternative and automate it. A comment saying "install manually" is not a solution.

**User-first thinking** — Every decision is made from the perspective of someone cloning this repo on a fresh machine. They shouldn't read code comments or debug why something didn't install.

**Automation over documentation** — If an action can be automated, it must be automated. Documentation describes "how it works", not "what to do manually".

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
