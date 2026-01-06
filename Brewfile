# =============================================================================
# Brewfile — declarative package manifest for Homebrew
# =============================================================================
#
# This file defines all packages, casks, and taps to be installed via Homebrew.
# Managed by `brew bundle` command.
#
# Usage:
#   brew bundle              Install all packages from this Brewfile
#   brew bundle check        Check if all dependencies are installed
#   brew bundle cleanup      Uninstall packages not listed in Brewfile
#   brew bundle list         List all packages in Brewfile
#
# Updating this file:
#   brew bundle dump --force       Regenerate Brewfile from installed packages
#   brew bundle dump --describe    Include package descriptions (one-time)
#
# Example:
#   brew bundle --file=~/GitHub/dotfiles/Brewfile
#
# =============================================================================

# System utilities
brew "stow"              # GNU Stow: symlink farm manager for dotfiles
cask "raycast"           # Spotlight replacement with extensions and productivity features
cask "bluesnooze"        # Automatically disables Bluetooth when Mac goes to sleep

# Terminal
brew "starship"          # Cross-shell prompt customizer
brew "tmux"              # Terminal multiplexer for persistent sessions and panes
brew "pam-reattach"      # Enables Touch ID authentication in tmux sessions
cask "alacritty"         # GPU-accelerated cross-platform terminal emulator
cask "font-jetbrains-mono-nerd-font"  # JetBrains Mono font with Nerd Font icons for terminal

# File system
brew "eza"               # Modern replacement for `ls` with colors and icons
brew "fzf"               # Command-line fuzzy finder for files and history
brew "ncdu"              # NCurses disk usage analyzer with interactive interface
brew "zoxide"            # Smarter `cd` command that learns frequently used directories
brew "tree"              # Display directory structure in tree format
brew "ripgrep"           # Ultra-fast recursive text search tool (rg)

# Editors
brew "micro"             # Simple and intuitive terminal-based text editor
brew "neovim"            # Modern vim-based extensible text editor

# Version control
brew "gh"                # GitHub CLI for issues, PRs, and repository management

# Security / Secrets
brew "gnupg"                     # GnuPG for encryption (required for Doppler signature verification)
tap "dopplerhq/cli"
brew "doppler"                   # Doppler CLI for secrets management

# Languages and runtimes
brew "go"                # Go programming language compiler and tools
brew "pipx"              # Install and run Python CLI applications in isolated environments
brew "fnm"               # Fast Node.js version manager written in Rust
brew "pnpm"              # Fast, disk space efficient package manager for Node.js

# Data manipulation
brew "jq"                # Lightweight command-line JSON processor
brew "qsv"               # High-performance CSV data toolkit
brew "yq"                # Command-line YAML/XML/TOML processor (like jq for YAML)
brew "miller"            # Swiss-army knife for CSV, JSON, and tabular data (mlr)

# Infrastructure
cask "docker"            # Docker Desktop: containerization platform with GUI
tap "hashicorp/tap"
brew "hashicorp/tap/terraform"  # Infrastructure as Code tool for cloud provisioning

# Media
brew "ffmpeg"            # Complete solution for video/audio recording and conversion
brew "imagemagick"       # Image manipulation suite (convert, resize, transform)
brew "oxipng"            # Lossless PNG compression optimizer
brew "poppler"           # PDF rendering library with CLI tools (pdftotext, pdfinfo)
