# Andrey's dotfiles

Hey! 👋 I'm Andrey Vavilov ([@harmonyjs](https://github.com/harmonyjs)), and these are my personal dotfiles that I use daily for development.

This is my minimal yet powerful terminal setup for macOS with tmux + Alacritty. I've crafted these configurations over time to create a distraction-free, efficient development environment that just works.

---

## Features

- 🎨 Catppuccin Latte theme
- ⚡ Vim-style navigation in tmux
- 🖥️ GPU-accelerated Alacritty terminal
- 📦 One-command installation via GNU Stow

## Requirements

- macOS
- Homebrew
- tmux 3.2+
- GNU Stow

## Installation

```bash
# Clone repository with submodules
git clone --recurse-submodules https://github.com/harmonyjs/dotfiles.git ~/dotfiles
cd ~/dotfiles

# If already cloned, initialize submodules
git submodule update --init --recursive

# Install dependencies
brew install tmux stow

# Install Nerd Font (for icons in terminal)
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# Create symlinks (--no-folding needed for .claude directory)
stow -v --no-folding .

# Install tmux plugin manager (TPM)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Install tmux plugins
~/.tmux/plugins/tpm/bin/install_plugins
```

## Managing Symlinks

**Tip**: All stow commands include `-v` (verbose) flag for transparency. This shows exactly what symlinks are being created or removed, which is helpful for debugging.

### Full Reinstallation
To completely reinstall all symlinks:

```bash
# Remove all existing symlinks
stow -D -v --no-folding .

# Recreate all symlinks
stow -v --no-folding .
```

### Working with .claude Directory
The `.claude` directory is a git submodule containing Claude Code configurations. Since `~/.claude` already exists with runtime files (ide/, projects/, todos/), we use `--no-folding` to create individual file symlinks instead of replacing the entire directory:

```bash
# Initialize .claude submodule (if not done)
git submodule update --init .claude

# Create symlinks with --no-folding flag
stow -v --no-folding .

# Verify .claude symlinks
ls -la ~/.claude/ | grep '\->'
```

**Important**: The `--no-folding` flag tells Stow to symlink individual files within directories rather than symlinking entire directories. This preserves existing runtime directories in `~/.claude` while symlinking only the configuration files (settings.json, commands/, CLAUDE.md). Local configuration files (*.local.json) are ignored and should remain local to each machine.

## Quick Start

After installation, simply open Alacritty. It will automatically:
- Start a tmux session named "main"
- Apply the Catppuccin Latte theme
- Enable all configured keybindings

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

- `.tmux.conf` - Tmux configuration with custom keybindings
- `.alacritty.toml` - Terminal emulator settings
- `.zsh_aliases` - Useful shell aliases
- `.claude/` - Git submodule with Claude Code configurations (settings.json, commands/)

## Documentation

- [Tmux Reference](docs/TMUX.md) - Key bindings and troubleshooting
- [Alacritty Integration](docs/ALACRITTY.md) - Tmux integration specifics

## Testing

Run verification script:
```bash
./scripts/verify-setup.sh
```

## Troubleshooting

### Symlink Issues

**Problem**: Symlinks in `.claude` are not created properly
**Solution**: Use `--no-folding` flag:
```bash
stow -v --no-folding .
```

**Problem**: Stow tries to replace entire `~/.claude` directory
**Cause**: Without `--no-folding`, Stow attempts to symlink the directory itself
**Solution**: Always use `--no-folding` when `~/.claude` contains runtime files:
```bash
stow -v --no-folding .
```

**Problem**: Some symlinks point to wrong paths (relative vs absolute)
**Solution**: This is normal - stow creates relative symlinks from target directory

### Checking Symlink Status
```bash
# Check all dotfiles symlinks
ls -la ~/ | grep '\-> .*dotfiles'

# Check .claude symlinks specifically
ls -la ~/.claude/ | grep '\->'

# Verify symlinks are valid (not broken)
find ~/.claude -type l ! -exec test -e {} \; -print
```

### Verification
Always run the verification script after making changes:
```bash
./scripts/verify-setup.sh
```

## Uninstall

To remove all symlinks:
```bash
cd ~/dotfiles
stow -D -v --no-folding .
```

## License

MIT
