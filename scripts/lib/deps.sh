#!/usr/bin/env bash
# deps.sh - Dependency management functions
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# Required Dependencies
# =============================================================================

# Core dependencies (for verification)
REQUIRED_DEPS=(git tmux stow starship)
OPTIONAL_DEPS=(alacritty)

# Brewfile location
BREWFILE="$DOTFILES_DIR/Brewfile"

# =============================================================================
# Homebrew Functions
# =============================================================================

# Check if Homebrew is available
check_brew_available() {
    command -v brew &>/dev/null
}

# Ensure Homebrew is available (exit if not)
ensure_brew() {
    if check_brew_available; then
        log_success "Homebrew found"
        return 0
    fi

    log_error "Homebrew not found"
    echo
    echo "Homebrew is required to install dependencies."
    echo "Install it from: https://brew.sh"
    echo
    echo "Run this command:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
}

# =============================================================================
# Dependency Check Functions
# =============================================================================

# Check if a dependency is installed
# Returns 0 if installed, 1 if not
check_dependency() {
    local dep="$1"
    command -v "$dep" &>/dev/null
}

# Check tmux version (requires 3.2+)
check_tmux_version() {
    if ! check_dependency tmux; then
        return 1
    fi
    tmux -V | grep -Eq 'tmux 3\.[2-9]|tmux [4-9]'
}

# =============================================================================
# Dependency Installation Functions
# =============================================================================

# Install a dependency via brew
install_dependency() {
    local dep="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    brew install "$dep" 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    # Check if installation succeeded
    check_dependency "$dep"
}

# Ensure a dependency is installed (install if not)
ensure_dependency() {
    local dep="$1"
    local version

    if check_dependency "$dep"; then
        version=$(get_version "$dep")
        if [[ "$VERBOSE" == "true" ]]; then
            log_success "$dep ($version)"
        fi
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "$dep — would install via brew"
        return 0
    fi

    log_warning "$dep not installed"
    log_action "Installing..."

    if install_dependency "$dep"; then
        version=$(get_version "$dep")
        log_success "$dep ($version)"
        return 0
    else
        log_error "$dep — installation failed"
        return 1
    fi
}

# =============================================================================
# Brewfile Functions
# =============================================================================

# Check if all Brewfile packages are installed
check_brewfile() {
    if [[ ! -f "$BREWFILE" ]]; then
        return 1
    fi
    if brew bundle check --file="$BREWFILE" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Install packages from Brewfile
run_brew_bundle() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    brew bundle --file="$BREWFILE" 2>&1 | while read -r line; do
        # Show installing/upgrading progress
        if [[ "$line" =~ ^Installing|^Upgrading ]]; then
            echo -e "  ${DIM}→${NC} $line"
        elif [[ "$VERBOSE" == "true" ]]; then
            log_verbose "$line"
        fi
    done
}

# Ensure all Brewfile packages are installed
ensure_brewfile() {
    if [[ ! -f "$BREWFILE" ]]; then
        log_warning "Brewfile not found"
        return 1
    fi

    if check_brewfile; then
        log_success "All Brewfile packages installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Brewfile packages — would install via brew bundle"
        return 0
    fi

    log_warning "Some Brewfile packages missing"
    log_action "Running brew bundle..."

    if run_brew_bundle && check_brewfile; then
        log_success "Brewfile packages installed"
        return 0
    else
        log_error "brew bundle failed"
        return 1
    fi
}

# =============================================================================
# Main Dependencies Function
# =============================================================================

# Ensure all required dependencies are installed
ensure_all_dependencies() {
    local failed=0

    # Use Brewfile if available
    if [[ -f "$BREWFILE" ]]; then
        if ! ensure_brewfile; then
            ((failed++))
        fi
    else
        # Fallback to individual installs
        for dep in "${REQUIRED_DEPS[@]}"; do
            if ! ensure_dependency "$dep"; then
                ((failed++))
            fi
        done
    fi

    # Special check for tmux version
    if check_dependency tmux && ! check_tmux_version; then
        log_warning "tmux version too old (requires 3.2+)"
        if [[ "$DRY_RUN" != "true" ]]; then
            log_action "Upgrading..."
            brew upgrade tmux 2>&1 | while read -r line; do
                log_verbose "$line"
            done
        fi
    fi

    return $failed
}

# =============================================================================
# Font Installation
# =============================================================================

# Check if JetBrainsMono Nerd Font is installed
check_nerd_font() {
    # Check in user fonts directory
    if ls ~/Library/Fonts/JetBrainsMono*.ttf &>/dev/null; then
        return 0
    fi
    # Check in system fonts directory
    if ls /Library/Fonts/JetBrainsMono*.ttf &>/dev/null; then
        return 0
    fi
    # Check via fc-list if available
    if command -v fc-list &>/dev/null; then
        fc-list | grep -qi "JetBrainsMono Nerd Font" && return 0
    fi
    return 1
}

# Install Nerd Font via brew cask
install_nerd_font() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Tap the fonts cask if needed
    brew tap homebrew/cask-fonts 2>/dev/null || true

    brew install --cask font-jetbrains-mono-nerd-font 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    check_nerd_font
}

# Ensure Nerd Font is installed
ensure_nerd_font() {
    if check_nerd_font; then
        log_success "Nerd Font installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "JetBrainsMono Nerd Font — would install"
        return 0
    fi

    log_warning "Nerd Font not installed"
    log_action "Installing JetBrainsMono Nerd Font..."

    if install_nerd_font; then
        log_success "Font installed"
        return 0
    else
        log_warning "Font installation failed (optional)"
        return 0  # Non-fatal
    fi
}

# =============================================================================
# Rustup Installation (official method via curl)
# =============================================================================

# Check if rustup/cargo is installed
check_rustup() {
    command -v rustup &>/dev/null && command -v cargo &>/dev/null
}

# Install rustup via official script
install_rustup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    # Source cargo env for current session
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi

    check_rustup
}

# Ensure rustup is installed
ensure_rustup() {
    if check_rustup; then
        local version
        version=$(rustup --version 2>/dev/null | head -1 | awk '{print $2}')
        log_success "rustup ($version)"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "rustup — would install via official script"
        return 0
    fi

    log_warning "rustup not installed"
    log_action "Installing via official script..."

    if install_rustup; then
        local version
        version=$(rustup --version 2>/dev/null | head -1 | awk '{print $2}')
        log_success "rustup ($version)"
        return 0
    else
        log_error "rustup — installation failed"
        return 1
    fi
}

# =============================================================================
# Yandex Cloud CLI (official method via curl)
# =============================================================================

# Check if yc is installed
check_yc() {
    command -v yc &>/dev/null
}

# Install yc via official script
install_yc() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    local yc_dir="$HOME/.local/yandex-cloud"
    local bin_dir="$HOME/.local/bin"

    # Install to isolated directory
    mkdir -p "$bin_dir"
    curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash -s -- -i "$yc_dir" -n 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    # Create symlinks to XDG-compliant location
    if [[ -f "$yc_dir/bin/yc" ]]; then
        ln -sf "$yc_dir/bin/yc" "$bin_dir/yc"
    fi
    if [[ -f "$yc_dir/bin/docker-credential-yc" ]]; then
        ln -sf "$yc_dir/bin/docker-credential-yc" "$bin_dir/docker-credential-yc"
    fi

    # Add to PATH for current session if not already there
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        export PATH="$bin_dir:$PATH"
    fi

    check_yc
}

# Ensure yc is installed
ensure_yc() {
    if check_yc; then
        local version
        version=$(yc version 2>/dev/null | head -1 | awk '{print $4}')
        log_success "yc ($version)"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "yc — would install via official script"
        return 0
    fi

    log_warning "yc (Yandex Cloud CLI) not installed"
    log_action "Installing via official script..."

    if install_yc; then
        local version
        version=$(yc version 2>/dev/null | head -1 | awk '{print $4}')
        log_success "yc ($version)"
        return 0
    else
        log_error "yc — installation failed"
        return 1
    fi
}

# =============================================================================
# FZF Shell Integration
# =============================================================================

# Check if fzf shell integration is set up
check_fzf_shell() {
    [[ -f "$HOME/.fzf.zsh" ]]
}

# Install fzf shell integration (key bindings + completion)
install_fzf_shell() {
    local fzf_install="$(brew --prefix)/opt/fzf/install"

    if [[ ! -x "$fzf_install" ]]; then
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    "$fzf_install" --all --no-bash --no-fish --no-update-rc 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    check_fzf_shell
}

# Ensure fzf shell integration is set up
ensure_fzf_shell() {
    if ! check_dependency fzf; then
        log_verbose "fzf not installed, skipping shell integration"
        return 0
    fi

    if check_fzf_shell; then
        log_success "fzf shell integration"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "fzf shell integration — would configure"
        return 0
    fi

    log_warning "fzf shell integration not configured"
    log_action "Running fzf install..."

    if install_fzf_shell; then
        log_success "fzf shell integration configured"
        return 0
    else
        log_warning "fzf shell integration failed (optional)"
        return 0  # Non-fatal
    fi
}

# =============================================================================
# Corepack Shims (yarn, pnpm via Node.js corepack)
# =============================================================================

# Activate fnm for bash scripts (where .zshrc is not loaded)
activate_fnm() {
    if command -v fnm &>/dev/null; then
        eval "$(fnm env)"
    fi
}

# Check if a command is a corepack shim (not a Homebrew binary)
is_corepack_shim() {
    local cmd="$1"
    local cmd_path
    cmd_path=$(command -v "$cmd" 2>/dev/null) || return 1
    local target
    target=$(readlink "$cmd_path" 2>/dev/null) || return 1
    [[ "$target" == *corepack* ]]
}

# Check if all corepack shims are set up
check_corepack_shims() {
    is_corepack_shim yarn && is_corepack_shim pnpm
}

# Install corepack shims
install_corepack_shims() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    corepack enable yarn pnpm 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    check_corepack_shims
}

# Ensure corepack shims are set up
ensure_corepack_shims() {
    # Skip if Node.js is not available
    if ! command -v node &>/dev/null; then
        log_verbose "Node.js not available, skipping corepack shims"
        return 0
    fi

    if check_corepack_shims; then
        log_success "corepack shims (yarn, pnpm)"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "corepack shims — would enable yarn and pnpm"
        return 0
    fi

    log_warning "corepack shims not configured"
    log_action "Running corepack enable..."

    if install_corepack_shims; then
        log_success "corepack shims (yarn, pnpm)"
        return 0
    else
        log_error "corepack enable failed"
        return 1
    fi
}

# =============================================================================
# Summary Functions
# =============================================================================

# Print a compact summary of all dependencies
print_deps_summary() {
    local installed=()
    local missing=()

    for dep in "${REQUIRED_DEPS[@]}"; do
        if check_dependency "$dep"; then
            installed+=("$dep")
        else
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        local deps_str
        deps_str=$(printf '%s, ' "${installed[@]}" | sed 's/, $//')
        log_success "$deps_str"
    else
        for dep in "${installed[@]}"; do
            log_success "$dep"
        done
        for dep in "${missing[@]}"; do
            log_error "$dep — missing"
        done
    fi
}
