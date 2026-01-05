#!/usr/bin/env bash
# tmux.sh - Tmux-specific functions
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# TPM (Tmux Plugin Manager) Functions
# =============================================================================

TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"

# Check if TPM is installed
is_tpm_installed() {
    [[ -d "$TPM_DIR" ]] && [[ -f "$TPM_DIR/tpm" ]]
}

# Install TPM
install_tpm() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    git clone "$TPM_REPO" "$TPM_DIR" 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    is_tpm_installed
}

# Ensure TPM is installed
ensure_tpm() {
    if is_tpm_installed; then
        log_success "TPM installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "TPM — would install"
        return 0
    fi

    log_warning "TPM not installed"
    log_action "Installing..."

    if install_tpm; then
        log_success "TPM installed"
        return 0
    else
        log_error "TPM — installation failed"
        return 1
    fi
}

# =============================================================================
# Plugin Functions
# =============================================================================

TMUX_PLUGINS=(
    tmux              # Catppuccin theme
    tmux-sensible
    tmux-yank
)

# Check if a plugin is installed
is_plugin_installed() {
    local plugin="$1"
    [[ -d "$HOME/.tmux/plugins/$plugin" ]]
}

# Install all plugins via TPM
install_plugins() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
        "$TPM_DIR/bin/install_plugins" 2>&1 | while read -r line; do
            log_verbose "$line"
        done
        return 0
    else
        return 1
    fi
}

# Ensure all plugins are installed
ensure_plugins() {
    # Check if all plugins are installed
    local all_installed=true
    for plugin in "${TMUX_PLUGINS[@]}"; do
        if ! is_plugin_installed "$plugin"; then
            all_installed=false
            break
        fi
    done

    if [[ "$all_installed" == "true" ]]; then
        log_success "Tmux plugins"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Tmux plugins — would install"
        return 0
    fi

    log_warning "Tmux plugins not installed"
    log_action "Installing..."

    if install_plugins; then
        log_success "Tmux plugins"
        return 0
    else
        log_warning "Tmux plugins — installation failed (run prefix+I in tmux)"
        return 0  # Non-fatal
    fi
}

# =============================================================================
# Config Functions
# =============================================================================

# Load tmux configuration
load_config() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    tmux start-server 2>/dev/null
    tmux source-file ~/.tmux.conf 2>/dev/null
}

# Ensure config is loaded
ensure_config_loaded() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if load_config; then
        log_success "Tmux config loaded"
        return 0
    else
        log_info "Tmux config will load on next tmux start"
        return 0  # Non-fatal
    fi
}

# =============================================================================
# Check Functions (for check script)
# =============================================================================

# Check tmux configuration
check_tmux_config() {
    local total=0
    local passed=0

    # Config loads without errors
    ((total++))
    if tmux start-server && tmux source-file ~/.tmux.conf 2>/dev/null || tmux show -g prefix &>/dev/null; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Config loads without errors"
    else
        log_error "Config fails to load"
    fi

    # Prefix key
    ((total++))
    if tmux show -g prefix 2>/dev/null | grep -q 'C-Space'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Prefix is C-Space"
    else
        log_error "Prefix is not C-Space"
    fi

    # Mouse support
    ((total++))
    if tmux show -g mouse 2>/dev/null | grep -q 'on'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Mouse enabled"
    else
        log_error "Mouse disabled"
    fi

    # True color
    ((total++))
    if tmux info 2>/dev/null | grep -Eq 'RGB|Tc'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "True color support"
    else
        log_error "No true color support"
    fi

    # Vi mode
    ((total++))
    if tmux show -gw mode-keys 2>/dev/null | grep -q 'vi'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Vi mode enabled"
    else
        log_error "Vi mode disabled"
    fi

    # Base index
    ((total++))
    if tmux show -g base-index 2>/dev/null | grep -q '1$'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Windows start at 1"
    else
        log_error "Windows don't start at 1"
    fi

    # Renumber windows
    ((total++))
    if tmux show -g renumber-windows 2>/dev/null | grep -q 'on'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Window renumbering enabled"
    else
        log_error "Window renumbering disabled"
    fi

    echo "$passed/$total"
}

# Check plugins
check_plugins() {
    local total=0
    local passed=0

    # TPM
    ((total++))
    if is_tpm_installed; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "TPM installed"
    else
        log_error "TPM not installed"
    fi

    # Plugins
    for plugin in "${TMUX_PLUGINS[@]}"; do
        ((total++))
        if is_plugin_installed "$plugin"; then
            ((passed++))
            [[ "$VERBOSE" == "true" ]] && log_success "$plugin installed"
        else
            log_error "$plugin not installed"
        fi
    done

    echo "$passed/$total"
}

# Check key bindings
check_keybindings() {
    local total=0
    local passed=0

    # Prefix binding
    ((total++))
    if tmux list-keys -T prefix 2>/dev/null | grep -q 'C-Space.*send-prefix'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "C-Space prefix binding"
    else
        log_error "C-Space prefix binding missing"
    fi

    # Vim navigation
    ((total++))
    if tmux list-keys -T root 2>/dev/null | grep -q 'C-h.*select-pane -L'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Vim navigation (C-h)"
    else
        log_error "Vim navigation missing"
    fi

    # Alt+Arrow navigation
    ((total++))
    if tmux list-keys -T root 2>/dev/null | grep -q 'M-Left.*select-pane'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Alt+Arrow navigation"
    else
        log_error "Alt+Arrow navigation missing"
    fi

    # Shift+Arrow windows
    ((total++))
    if tmux list-keys -T root 2>/dev/null | grep -q 'S-Left.*previous-window'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Shift+Arrow windows"
    else
        log_error "Shift+Arrow windows missing"
    fi

    # Copy mode bindings
    ((total++))
    if tmux list-keys -T copy-mode-vi 2>/dev/null | grep -E 'v .*begin-selection|y .*copy-selection' >/dev/null; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Copy mode bindings"
    else
        log_error "Copy mode bindings missing"
    fi

    echo "$passed/$total"
}
