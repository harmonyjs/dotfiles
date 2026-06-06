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
brew "dockutil"          # Command-line tool for managing macOS Dock items
brew "just"              # Command runner, modern Make alternative
brew "mkcert"            # Local TLS certificate authority for development
brew "pipx"              # Python application installer in isolated venvs
brew "shellcheck"        # Static analysis linter for shell scripts
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
# GUI editors/IDEs (Claude, VS Code, JetBrains Toolbox, Android Studio) are
# installed manually from official dmg/installers, not via brew cask.
brew "micro"             # Simple and intuitive terminal-based text editor
brew "neovim"            # Modern vim-based extensible text editor

# Version control
brew "gh"                # GitHub CLI for issues, PRs, and repository management

# Security / Secrets
brew "gnupg"                     # GnuPG for encryption (required for Doppler signature verification)
tap "dopplerhq/cli"
brew "doppler"                   # Doppler CLI for secrets management
# 1Password desktop: install manually from https://1password.com/downloads
# Required for SSH agent + git commit signing; scripts/bootstrap waits for it
cask "1password-cli"             # 1Password command-line tool for secrets and credentials

# Languages and runtimes
brew "go"                # Go programming language compiler and tools
brew "uv"                # Fast Python package manager with pip, venv, and pipx-like tool management
brew "fnm"               # Fast Node.js version manager written in Rust
brew "bun"               # Incredibly fast JavaScript runtime, bundler, test runner & package manager
brew "cocoapods"         # CocoaPods: Swift/Objective-C dependency manager

# Data manipulation
brew "jq"                # Lightweight command-line JSON processor
brew "qsv"               # High-performance CSV data toolkit
brew "yq"                # Command-line YAML/XML/TOML processor (like jq for YAML)
brew "miller"            # Swiss-army knife for CSV, JSON, and tabular data (mlr)
brew "duckdb"            # In-process analytical SQL database (like SQLite for OLAP)
brew "pandoc"            # Universal document converter (Markdown, HTML, LaTeX, etc.)
brew "qpdf"              # PDF transformation, inspection, and repair toolkit
brew "typst"             # Modern typesetting system (LaTeX alternative)

# Infrastructure
tap "hashicorp/tap"
brew "hashicorp/tap/terraform"   # Infrastructure as Code tool for cloud provisioning
brew "kubernetes-cli"    # kubectl: Kubernetes command-line client
brew "k9s"               # Terminal UI for managing Kubernetes clusters
brew "cloudflared"       # Cloudflare Tunnel daemon (expose localhost to internet)
brew "libpq"             # PostgreSQL client library (psql, pg_dump, pg_restore)
brew "kcat"              # Apache Kafka CLI producer/consumer (formerly kafkacat)
cask "clickhouse"        # ClickHouse: column-oriented analytical database
# Yandex Cloud CLI: install manually via curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash

# Media
brew "ffmpeg"            # Complete solution for video/audio recording and conversion
brew "imagemagick"       # Image manipulation suite (convert, resize, transform)
brew "oxipng"            # Lossless PNG compression optimizer (Rust)
brew "jpegoptim"         # JPEG lossless/lossy optimizer
brew "optipng"           # PNG file size optimizer (classic)
brew "poppler"           # PDF rendering library with CLI tools (pdftotext, pdfinfo)
brew "yt-dlp"            # Video downloader for YouTube and many other sites
brew "aria2"             # Multi-protocol download utility with parallel connections
brew "qrencode"          # Generate QR codes from text on the command line

# Mobile / iOS development
brew "ios-webkit-debug-proxy"   # Debug Safari on iOS devices via Chrome DevTools protocol
brew "xcsift"                   # Modern xcpretty replacement: format Xcode build logs

# Note: GUI applications (messengers, browsers, productivity, office, design tools)
# are installed manually from their official dmg/installers — not via brew cask.
