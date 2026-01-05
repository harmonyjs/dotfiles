# Dotfiles Repository

Personal macOS terminal environment: tmux + Alacritty with Catppuccin Latte theme, vim-style navigation, and GNU Stow symlink management.

## Documentation

- **[README.md](README.md)** - Complete guide: installation, usage, troubleshooting
- **[AGENTS.md](AGENTS.md)** - AI agent instructions and workflow scenarios
- **[docs/TMUX.md](docs/TMUX.md)** - Tmux keybindings and commands reference
- **[docs/ALACRITTY.md](docs/ALACRITTY.md)** - Alacritty-tmux integration details

## Key Concepts

- **GNU Stow** manages symlinks from repo to `~` directory
- **`.stow-local-ignore`** defines files excluded from symlinking
- **`--no-folding`** flag required for `.claude` directory
- **`./scripts/verify-setup.sh`** validates entire setup
- **`.claude/`** is a git submodule with Claude Code configs

## Repository Structure

- `.tmux.conf` - tmux config (prefix: `Ctrl+Space`)
- `.alacritty.toml` - terminal with auto-start tmux session "main"
- `.zshrc` - shell config (sources `.zsh_aliases` and `.zshrc.local`)
- `.zsh_aliases` - command aliases

## AI Agent Guidelines

**Before changes:**
1. Read [AGENTS.md](AGENTS.md) for detailed scenarios
2. Run `./scripts/verify-setup.sh` to check current state
3. Create backups before modifying configs

**After changes:**
1. Run `./scripts/verify-setup.sh` - all checks must pass
2. Update docs if keybindings or behavior changed
3. Preserve Catppuccin Latte theme (critical requirement)

**Critical rules:**
- Maintain macOS + Homebrew compatibility
- Always use stow for symlink management
- Create backups before config modifications
- NEVER create symlinks manually, stow has to manage them
