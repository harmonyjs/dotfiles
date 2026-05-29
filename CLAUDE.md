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
- **`./scripts/bootstrap`** (or `just bootstrap <git-url>`) — entrypoint for a brand-new Mac. Walks from blank macOS install to fully configured environment, with one manual gate for 1Password desktop. The gate is **conditional** (skipped when SSH already authenticates). Supports `--dry-run` (preview, change nothing) and `-y/--yes` (unattended — never block on a prompt; human/sudo-gated steps skip with a note). See [AGENTS.md](AGENTS.md) Scenario 4.
- **`./scripts/init`** (or `just init`) — idempotent setup: brew bundle, submodules, stow, tmux plugins. Safe to re-run anytime.
- **`./scripts/post-install`** (or `just post-install`) — one-shot system tweaks: TouchID for sudo via `/etc/pam.d/sudo_local` and SSH `known_hosts` for github.com. **Sudo-aware**: skips the root-only TouchID write (with a note) when sudo isn't available, e.g. under `bootstrap -y`. Does not touch the hostname.
- **`./scripts/check`** (or `just check`) validates entire setup
- **`scripts/lib/git.sh`** — `ssh_ready` (1Password agent holds a key **and** GitHub authenticates it; side-effect-free probe) and `ensure_ssh_remote` (converges `origin` HTTPS → SSH, but only once `ssh_ready` passes; never downgrades). `init` runs `ensure_ssh_remote` every time, so the remote **self-heals** to SSH after you unlock 1Password; `check` reports a "Git remote" section; `bootstrap`'s manual 1Password gate is skipped whenever `ssh_ready` already passes.
- **`.claude/`** is a git submodule with Claude Code configs
- **`.private/`** is a git submodule with identity-bearing and machine-specific configs (see Repository Structure below for current scope)

## Repository Structure

**Public tree (this repo):**
- `.config/tmux/tmux.conf` - tmux config (prefix: `Ctrl+Space`)
- `.config/alacritty/alacritty.toml` - terminal with auto-start tmux session "main"
- `.zshenv` - environment variables and PATH (loaded always)
- `.zprofile` - login shell config (intentionally empty)
- `.zshrc` - interactive shell config (sources `.zsh_aliases` and `.zshrc.local`)
- `.zsh_aliases` - command aliases
- `Brewfile` - declarative Homebrew package manifest (CLIs, fonts, headless utilities only)
- `scripts/bootstrap`, `scripts/init`, `scripts/post-install`, `scripts/check`, `scripts/update`, `scripts/dry-run` - lifecycle scripts (sourced from `scripts/lib/*.sh`)

**`.private/` submodule (identity-bearing, machine-specific):**
- `.config/git/config`, `.config/git/allowed_signers` - git identity + SSH signing trust
- `.ssh/config`, `.ssh/*.pub` - SSH client config and public keys for this user
- `.config/1Password/ssh/agent.toml` - 1Password SSH agent config (serves keys from the `ssh` vault; versioned so a fresh machine doesn't get 1Password's empty `vault = "Personal"` default)
- `.zshrc.local`, `.zsh_history` - per-machine shell state
- `.codex/config.toml`, `.gemini/settings.json` - AI assistant per-tool configs
- `.config/imgcluster/.env`, `.config/tg-exporter/.env`, `.config/kcat.conf` - service-specific env/configs

**Public-vs-private rule:** anything that contains hostnames, public keys, email addresses, identity, credentials, or paths meaningful only to Andrey's specific machines belongs in `.private/`. The public tree is for curated tool choices and universal patterns that anyone can fork.

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

**No broken states** — Never commit changes that leave the setup non-functional. If something doesn't work via Homebrew, find an alternative and automate it. The only sanctioned manual gate is in `scripts/bootstrap` where the user installs 1Password desktop — and that gate is interactive, in-band, and clearly explained to the user; it is not a "go read the docs and figure it out" comment.

**User-first thinking** — Every decision is made from the perspective of someone cloning this repo on a fresh machine. They shouldn't read code comments or debug why something didn't install.

**Automation over documentation** — If an action can be automated and the policy permits it, it must be automated. The cask-vs-dmg policy (see below) is an explicit exception: desktop GUI apps are intentionally installed manually because that's the curated update path, not because automation is infeasible.

**Curated tool sourcing** — Homebrew is for CLIs, fonts, and headless system utilities. Desktop GUI apps (editors/IDEs, messengers, productivity, browsers, 1Password desktop, office suites) are installed from their official `.dmg`. When adding a new package: if it ships a GUI app you'd otherwise launch from Spotlight, do not add it as `cask "<name>"` to the Brewfile — note it in README/AGENTS or leave it implicit.

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
