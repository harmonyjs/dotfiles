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

TMUX_CONF="$HOME/.config/tmux/tmux.conf"
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
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
    [[ -d "$HOME/.config/tmux/plugins/$plugin" ]]
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

# Load tmux configuration (reload into running server, or no-op)
load_config() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    tmux source-file "$TMUX_CONF" 2>/dev/null
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

# Query a tmux option by loading config into a temporary server
# Usage: tmux_option show_flag option_name
# Examples: tmux_option -g prefix, tmux_option -gw mode-keys
tmux_option() {
    tmux -f "$TMUX_CONF" start-server \; show "$@" 2>/dev/null
}

# Check tmux configuration
check_tmux_config() {
    local total=0
    local passed=0

    # Config loads without errors
    ((total++))
    if tmux_option -g prefix &>/dev/null; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Config loads without errors"
    else
        log_error "Config fails to load"
        # All subsequent checks will fail too — bail early
        echo "$passed/$total"
        return
    fi

    # Prefix key
    ((total++))
    if tmux_option -g prefix | grep -q 'C-Space'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Prefix is C-Space"
    else
        log_error "Prefix is not C-Space"
    fi

    # Mouse support
    ((total++))
    if tmux_option -g mouse | grep -q 'on'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Mouse enabled"
    else
        log_error "Mouse disabled"
    fi

    # True color (check terminal-overrides for Tc flag)
    ((total++))
    if tmux_option -g terminal-overrides | grep -q 'Tc'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "True color support"
    else
        log_error "No true color support"
    fi

    # Vi mode
    ((total++))
    if tmux_option -gw mode-keys | grep -q 'vi'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Vi mode enabled"
    else
        log_error "Vi mode disabled"
    fi

    # Base index
    ((total++))
    if tmux_option -g base-index | grep -q '1$'; then
        ((passed++))
        [[ "$VERBOSE" == "true" ]] && log_success "Windows start at 1"
    else
        log_error "Windows don't start at 1"
    fi

    # Renumber windows
    ((total++))
    if tmux_option -g renumber-windows | grep -q 'on'; then
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
