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
# You can clone to any location - examples:
#   ~/dotfiles
#   ~/Projects/github/dotfiles
#   ~/dev/dotfiles
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
# IMPORTANT: -t ~ ensures symlinks are created in home directory
# This works regardless of where you cloned the repo
stow -v -t ~ --no-folding .

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
stow -D -v -t ~ --no-folding .

# Recreate all symlinks
stow -v -t ~ --no-folding .
```

### Working with .claude Directory
The `.claude` directory is a git submodule containing Claude Code configurations. Since `~/.claude` already exists with runtime files (ide/, projects/, todos/), we use `--no-folding` to create individual file symlinks instead of replacing the entire directory:

```bash
# Initialize .claude submodule (if not done)
git submodule update --init .claude

# Create symlinks with --no-folding flag
stow -v -t ~ --no-folding .

# Verify .claude symlinks
ls -la ~/.claude/ | grep '\->'
```

**Important**: The `--no-folding` flag tells Stow to symlink individual files within directories rather than symlinking entire directories. This preserves existing runtime directories in `~/.claude` while symlinking only the configuration files (settings.json, commands/, CLAUDE.md). Local configuration files (*.local.json) are ignored and should remain local to each machine.

## Quick Start

After installation, simply open Alacritty. It will automatically:
- Start a tmux session named "main"
- Apply the Catppuccin Latte theme
- Enable all configured keybindings

## Daily Usage & Verification

### After Reboot / System Updates

**Good news**: Symlinks are permanent and survive reboots! 🎉

Once you've set up your dotfiles with `stow`, the symlinks persist across:
- Mac restarts and shutdowns
- macOS system updates
- Terminal restarts

Your configuration files will always stay linked to the git repository.

### Quick Health Check

To verify everything is working correctly (useful after reboots or macOS updates):

```bash
# Navigate to your dotfiles directory
cd ~/Projects/github/dotfiles  # or wherever you cloned it

# Run the verification script
./scripts/verify-setup.sh
```

This script checks:
- ✓ All required dependencies are installed
- ✓ Symlinks exist and point to correct files
- ✓ **Symlinks use relative paths** (not absolute)
- ✓ Tmux configuration loads without errors
- ✓ All key bindings are properly configured
- ✓ Plugins are installed and working

### When to Run Verification

Run `./scripts/verify-setup.sh` when:
- 🔄 After restarting your Mac (for peace of mind)
- 📦 After macOS system updates
- 🤔 Something doesn't work as expected
- 🔧 After making changes to dotfiles

### If Verification Fails

If checks fail, see the [Troubleshooting](#troubleshooting) section or try:

```bash
# Recreate all symlinks
stow -D -v -t ~ --no-folding . && stow -v -t ~ --no-folding .
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

- `.tmux.conf` - Tmux configuration with custom keybindings
- `.alacritty.toml` - Terminal emulator settings
- `.zshrc` - ZSH configuration with shared settings (sources `.zsh_aliases` and `.zshrc.local`)
- `.zsh_aliases` - Useful shell aliases
- `.claude/` - Git submodule with Claude Code configurations (settings.json, commands/)

### Machine-Specific Configuration

The `.zshrc` file sources `~/.zshrc.local` for machine-specific settings that shouldn't be version controlled. Create this file to add:
- Company/organization-specific configurations
- Machine-specific PATH modifications
- Local development environment settings

Example `~/.zshrc.local`:
```bash
# Machine-specific ZSH Configuration

# Custom PATH additions
export PATH="$PATH:/custom/path/bin"

# Organization-specific settings
export NODE_EXTRA_CA_CERTS=/path/to/custom/cert
```

## Documentation

- [Tmux Reference](docs/TMUX.md) - Key bindings and troubleshooting
- [Alacritty Integration](docs/ALACRITTY.md) - Tmux integration specifics

## Troubleshooting

### Symlink Issues

**Problem**: Stow fails with "existing target is not owned by stow" or creates symlinks in wrong directory
**Cause**: Without `-t ~`, stow uses parent directory of the repo as target
**Solution**: Always specify target directory with `-t ~`:
```bash
stow -v -t ~ --no-folding .
```

**Problem**: Symlinks in `.claude` are not created properly
**Solution**: Use `--no-folding` flag:
```bash
stow -v -t ~ --no-folding .
```

**Problem**: Stow tries to replace entire `~/.claude` directory
**Cause**: Without `--no-folding`, Stow attempts to symlink the directory itself
**Solution**: Always use `--no-folding` when `~/.claude` contains runtime files:
```bash
stow -v -t ~ --no-folding .
```

**Problem**: Some symlinks use absolute paths instead of relative
**Cause**: Manual symlink creation or old stow version
**Solution**: Remove absolute symlinks and recreate with stow:
```bash
# Example: remove absolute .zshrc symlink
rm ~/.zshrc

# Recreate with stow (creates relative symlink)
stow -v -t ~ --no-folding .
```

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

To verify your setup is working correctly, see the [Daily Usage & Verification](#daily-usage--verification) section.

Quick command:
```bash
./scripts/verify-setup.sh
```

## Uninstall

To remove all symlinks:
```bash
# Navigate to your dotfiles directory (adjust path if needed)
cd ~/Projects/github/dotfiles

# Remove all symlinks
stow -D -v -t ~ --no-folding .
```

## License

MIT
