# Andrey's dotfiles

Hey! I'm Andrey Vavilov ([@harmonyjs](https://github.com/harmonyjs)), and these are my personal dotfiles that I use daily for development.

This is my minimal yet powerful terminal setup for macOS with tmux + Alacritty. I've crafted these configurations over time to create a distraction-free, efficient development environment that just works.

---

## Features

- Catppuccin Latte theme
- Vim-style navigation in tmux
- GPU-accelerated Alacritty terminal
- Starship prompt
- One-command installation

## Principles

**Zero-friction setup** — Clone, run `just init`, and everything works. No manual steps, no "install this separately" instructions. If it's in the setup, it's automated.

**Reproducibility** — `just check` passes 100% on any fresh macOS machine. The setup is deterministic and verified by automated checks.

## Quick Start

```bash
git clone https://github.com/harmonyjs/dotfiles.git ~/dotfiles
cd ~/dotfiles
just init
```

That's it! The `init` command handles everything automatically:
- Installs all packages from `Brewfile` via `brew bundle`
- Initializes git submodules
- Creates all symlinks
- Installs tmux plugins

## Commands

| Command | Description |
|---------|-------------|
| `just init` | Initialize or repair setup |
| `just check` | Verify configuration |
| `just preview` | Preview what init would do |
| `just update` | Pull latest updates |
| `just stow` | Apply symlinks via stow |
| `just brew` | Install Brewfile packages |
| `just tmux-reload` | Reload tmux configuration |

Run `just` to see all available commands.

### Command Options

All commands support these flags:
- `--verbose` or `-v` — Show detailed output
- `--help` or `-h` — Show help message

Examples:
```bash
just check --verbose    # Detailed verification
just init --dry-run     # Same as just preview
```

## Key Bindings

### Tmux Prefix
- `Ctrl+Space` - Main prefix key (instead of default `Ctrl+b`)

### Navigation (No Prefix Needed)
- `Ctrl+h/j/k/l` - Navigate between panes (vim-style)
- `Alt+Arrow Keys` - Navigate between panes
- `Shift+Left/Right` - Switch between windows
- `Alt+h/l` - Switch between windows (vim-style)

### Window Management
- `Prefix + "` - Split horizontally
- `Prefix + %` - Split vertically

## What's Included

- `.config/tmux/tmux.conf` - Tmux configuration with custom keybindings
- `.config/alacritty/alacritty.toml` - Terminal emulator settings
- `.config/starship.toml` - Starship prompt configuration
- `.zshrc` - ZSH configuration (sources `.zsh_aliases` and `.zshrc.local`)
- `.zsh_aliases` - Useful shell aliases
- `.claude/` - Git submodule with Claude Code configurations
- `.private/` - Optional git submodule for private configurations (includes `.config/git/config`)

### ZSH Configuration Files

ZSH loads configuration files in a specific order. This repository follows a clear separation of concerns:

| File | When Loaded | Purpose |
|------|-------------|---------|
| `.zshenv` | Always (all shells) | PATH and environment variables |
| `.zprofile` | Login shells only | Empty (reserved for login-only setup) |
| `.zshrc` | Interactive shells | Prompt, completion, aliases, utilities |

**Why this structure?**

- **`.zshenv`** runs for every shell invocation — interactive terminals, scripts, cron jobs. All PATH modifications (Homebrew, cargo, pnpm) and environment variables (proxy settings) live here for universal availability.
- **`.zprofile`** is intentionally empty. Everything that might be needed in non-login shells has been moved to `.zshenv`.
- **`.zshrc`** contains interactive-only features: prompt (Starship), completion, key bindings, shell utilities (fzf, zoxide), and sources aliases.

### Machine-Specific Configuration

The `.zshrc` file sources `~/.zshrc.local` for machine-specific settings. Create this file for:
- Company/organization-specific configurations
- Machine-specific PATH modifications
- Local development environment settings

Example `~/.zshrc.local`:
```bash
# Machine-specific ZSH Configuration
export PATH="$PATH:/custom/path/bin"
export NODE_EXTRA_CA_CERTS=/path/to/custom/cert
```

## Documentation

- [Tmux Reference](docs/TMUX.md) - Key bindings and troubleshooting
- [Alacritty Integration](docs/ALACRITTY.md) - Tmux integration specifics

## Advanced Usage

### Managing Symlinks Manually

If you need to manage symlinks manually:

```bash
# Remove all symlinks
stow -D -v -t ~ --no-folding .

# Recreate all symlinks
stow -v -t ~ --no-folding .
```

### Private Dotfiles

The `.private/` submodule contains machine-specific private configurations:
- `.zshrc.local` - Machine-specific zsh configuration
- `.zsh_history` - Shell command history

Private files are handled automatically by `just init`. If you have access to the private repository, initialize it manually:

```bash
git submodule update --init .private
just init
```

### Understanding --no-folding

The `--no-folding` flag tells Stow to symlink individual files within directories rather than symlinking entire directories. This is essential for `.claude/` which contains runtime files that shouldn't be replaced.

## Troubleshooting

Run `just check --verbose` to see detailed status of all components.

If checks fail:
```bash
just init
```

The `init` command is idempotent — safe to run multiple times. It will repair any issues automatically.

## Uninstall

```bash
cd ~/dotfiles
stow -D -v -t ~ --no-folding .
```

## License

MIT
