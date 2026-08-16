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

# Run commit-pr-guide hook tests
test-commit-guide:
    bash .claude/hooks/commit-pr-guide.test.sh

# Run stop-ask-user hook tests
test-stop-ask:
    bash .claude/hooks/stop-ask-user.test.sh

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
