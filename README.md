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

**Zero-friction setup** — Clone, run `just init`, and the CLI/terminal environment works. The one unavoidable manual step is installing 1Password desktop from its official `.dmg` (`bootstrap` pauses until that's done), because the SSH agent it provides has to exist before any submodule or GitHub operation.

**Reproducibility** — `just check` passes 100% on any fresh macOS machine. The setup is deterministic and verified by automated checks.

**Curated tool sourcing** — Homebrew is the package manager for CLIs, fonts, and headless system utilities. Desktop GUI apps (editors, IDEs, messengers, browsers, productivity, 1Password) are installed from their official `.dmg`, so updates ship through the vendor's native channel.

## Quick Start

If you already have an existing macOS environment (Homebrew, git, SSH) and just want to apply these dotfiles:

```bash
git clone https://github.com/harmonyjs/dotfiles.git ~/GitHub/dotfiles
cd ~/GitHub/dotfiles
just init
```

The `init` command handles the bulk of setup:
- Installs all packages from `Brewfile` via `brew bundle`
- Initializes git submodules (including `.claude/`, and `.private/` if you have access)
- Creates all symlinks via stow
- Installs tmux plugins

## Fresh macOS Bootstrap

On a brand-new Mac (or after a clean install) where Homebrew, Xcode CLT and 1Password are not yet present, use `bootstrap` instead of `init`. It walks from a blank macOS install to a fully configured environment in one command:

```bash
curl -fsSL https://raw.githubusercontent.com/harmonyjs/dotfiles/main/scripts/bootstrap \
  | bash -s -- https://github.com/<your-user>/dotfiles.git
```

What `bootstrap` does:

1. Caches `sudo` ticket for the run
2. Installs Xcode Command Line Tools (GUI prompt — accept it)
3. Installs Homebrew
4. Clones the dotfiles repo over HTTPS (SSH not yet available)
5. Installs **1Password CLI** via Homebrew
6. **Manual gate:** prompts you to download 1Password desktop from <https://1password.com/downloads/mac/>, sign in, enable the SSH agent + git commit signing in Settings → Developer, and add your SSH key to GitHub as **both** auth and signing key
7. Switches the dotfiles remote `origin` from HTTPS to SSH (so submodules can fetch over SSH)
8. Initializes private submodules
9. Runs `scripts/init` (Brewfile, symlinks, plugins)
10. Runs `scripts/post-install` (TouchID for sudo, SSH known_hosts, hostname prompt)

**Why is 1Password desktop a manual step?** This repo treats Homebrew as the package manager for CLIs, fonts, and headless system utilities — not for desktop GUI apps. Desktop apps (editors, IDEs, messengers, browsers, 1Password) are installed from their official `.dmg` so updates flow through the vendor's native channel. `bootstrap` pauses at step 6 until 1Password is installed and signed in, because the SSH agent it provides is what every subsequent step relies on.

**Forking this repo?** Pass your fork's URL as the script argument (or set `DOTFILES_REPO=<url>` before running). The HTTPS → SSH remote switch is derived from the URL you supply, no hardcoded paths.

## Commands

| Command | Description |
|---------|-------------|
| `just bootstrap <git-url>` | Fresh macOS: Xcode CLT, Homebrew, clone, 1Password gate, init, post-install |
| `just init` | Initialize or repair setup (idempotent) |
| `just post-install` | One-time system tweaks (TouchID, known_hosts, hostname) |
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

The `.private/` submodule contains machine-specific or identity-bearing configurations that don't belong in a public repo:

- `.zshrc.local` — machine-specific zsh configuration
- `.zsh_history` — shell command history
- `.ssh/config`, `.ssh/*.pub` — SSH client config and your own public keys
- `.config/git/config`, `.config/git/allowed_signers` — git user identity and signing trust
- `.docker/daemon.json` — Docker daemon configuration
- `.codex/config.toml`, `.gemini/settings.json` — per-tool AI assistant configs
- `.config/imgcluster/.env`, `.config/tg-exporter/.env`, `.config/kcat.conf` — service credentials

This split is deliberate: the public dotfiles repo curates **tool choices and universal patterns** that anyone can fork and apply; `.private` holds **personal identity, hostnames, and credentials** that are only meaningful on Andrey's machines.

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
