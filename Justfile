# Dotfiles management commands
# Run `just` or `just help` to see available recipes

# Default recipe - show help
default:
    @just --list

# Fresh-macOS bootstrap: Xcode CLT, Homebrew, clone, 1Password gate, init, post-install
# Usage: just bootstrap <git-url>   (or auto-detect from existing clone)
bootstrap *ARGS:
    ./scripts/bootstrap {{ARGS}}

# Initialize or repair dotfiles setup (idempotent)
init *ARGS:
    ./scripts/init {{ARGS}}

# One-time system tweaks after init (TouchID, known_hosts, hostname)
post-install *ARGS:
    ./scripts/post-install {{ARGS}}

# Verify dotfiles setup (read-only)
check *ARGS:
    ./scripts/check {{ARGS}}

# Restore shared global instruction links through a scoped Stow operation
instructions *ARGS:
    ./scripts/instructions {{ARGS}}

# Check global instruction links without checking the rest of the machine
check-instructions:
    python3 .agents/instruction-layout/check.py

# Exercise Stow installation and conflict handling in temporary homes
test-instructions:
    python3 scripts/tests/instructions.test.py

# Update dotfiles from remote
update *ARGS:
    ./scripts/update {{ARGS}}

# Preview what init would do (dry-run)
preview *ARGS:
    ./scripts/dry-run {{ARGS}}

# Alias for preview
dry-run *ARGS:
    ./scripts/dry-run {{ARGS}}

# Apply symlinks via stow
stow:
    stow --restow --no-folding -t ~ .

# Link Claude Code memory dirs into the repo (idempotent)
memory:
    DOTFILES_DIR="{{justfile_directory()}}" bash -c 'source scripts/lib/common.sh && source scripts/lib/memory.sh && link_memory'

# Run memory linker unit tests
test-memory:
    bash scripts/tests/memory.test.sh

# Run stow dry-run check tests
test-stow-check:
    bash scripts/tests/stow-check.test.sh

# Run session-start-stow hook tests
test-session-start-stow:
    bash .claude/hooks/session-start-stow.test.sh

# Run commit-pr-guide hook tests
test-commit-guide:
    bash .claude/hooks/commit-pr-guide.test.sh

# Run stop-ask-user hook tests
test-stop-ask:
    bash .claude/hooks/stop-ask-user.test.sh

# Run delegation-guard hook tests
test-delegation-guard:
    python3 .claude/hooks/delegation-guard.test.py
    python3 scripts/tests/delegation-guard-stats.test.py

# Open the delegation-guard stats dashboard
delegation-stats:
    python3 scripts/delegation-guard-stats.py

# Open the portal with analytics for all Claude Code hooks
hooks-portal:
    python3 scripts/hooks-portal.py

# Run hook-run wrapper and hooks portal tests
test-hooks-portal:
    bash .claude/hooks/hook-run.test.sh
    python3 scripts/tests/hooks-portal.test.py

# Run zsh-bashism-guard hook tests
test-zsh-bashism:
    python3 .claude/hooks/zsh-bashism-guard.test.py

# Run merge-attribution-guard hook tests
test-merge-attribution:
    python3 .claude/hooks/merge-attribution-guard.test.py

# Run terrateam-stale-merge-guard hook tests
test-terrateam-stale-merge:
    python3 .claude/hooks/terrateam-stale-merge-guard.test.py

# Run gh-dashdash-guard hook tests
test-gh-dashdash:
    python3 .claude/hooks/gh-dashdash-guard.test.py

# Show symlink status
stow-status:
    stow --no --verbose -t ~ . 2>&1 | grep -E "^(LINK|UNLINK|MV)" || echo "No changes needed"

# Install Brewfile packages
brew:
    brew bundle --file=Brewfile

# Check which Brewfile packages are missing
brew-check:
    brew bundle check --file=Brewfile --verbose

# Reload tmux config
tmux-reload:
    tmux source-file ~/.tmux.conf && echo "tmux config reloaded"

# Install tmux plugins
tmux-plugins:
    ~/.config/tmux/plugins/tpm/bin/install_plugins
