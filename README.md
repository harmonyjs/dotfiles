# Dotfiles

This repository contains my personal dotfiles - configuration files used to customize various command-line tools and applications on Unix-like systems.

## What's Included

- **Alacritty** (.alacritty.toml) - Configuration for the Alacritty terminal emulator
- **Tmux** (.tmux.conf) - Terminal multiplexer configuration

## Prerequisites

- Git
- [GNU Stow](https://www.gnu.org/software/stow/) - Symlink farm manager
- [Alacritty](https://github.com/alacritty/alacritty) - A cross-platform, GPU-accelerated terminal emulator
- [Tmux](https://github.com/tmux/tmux) - Terminal multiplexer

## Installation

1. Clone this repository:
```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

2. Use GNU Stow to create symlinks:
```bash
stow .
```

This will create symbolic links in your home directory for all configuration files.

## Configuration Details

### Alacritty
The Alacritty configuration provides a modern terminal experience with:
- Custom color scheme
- Font configuration
- Window settings

### Tmux
The Tmux configuration includes:
- Custom key bindings
- Session management
- Status bar customization

## Inspiration
This dotfiles setup was inspired by:
- [Managing Your Dotfiles](https://www.youtube.com/watch?v=DzNmUNvnB04)

