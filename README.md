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
# Clone repository
git clone https://github.com/harmonyjs/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Install dependencies
brew install tmux stow

# Install Nerd Font (for icons in terminal)
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# Create symlinks
stow .

# Install tmux plugin manager (TPM)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Install tmux plugins
~/.tmux/plugins/tpm/bin/install_plugins
```

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

## Documentation

- [Tmux Reference](docs/TMUX.md) - Key bindings and troubleshooting
- [Alacritty Integration](docs/ALACRITTY.md) - Tmux integration specifics

## Testing

Run verification script:
```bash
./scripts/verify-setup.sh
```

## Uninstall

To remove all symlinks:
```bash
cd ~/dotfiles
stow -D .
```

## License

MIT
