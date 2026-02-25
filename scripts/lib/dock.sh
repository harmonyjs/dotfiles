#!/usr/bin/env bash
# dock.sh - macOS Dock management functions
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# Required Dock Items
# =============================================================================

DOCK_APPS=("Alacritty")

# =============================================================================
# Check Functions
# =============================================================================

# Check if dockutil is available
check_dockutil_available() {
    command -v dockutil &>/dev/null
}

# Check if a single app is in the Dock
# Usage: check_dock_item "Alacritty"
check_dock_item() {
    local app="$1"
    dockutil --find "$app" &>/dev/null
}

# Check all required Dock items
# Returns "passed/total" format for check script
check_dock() {
    if ! check_dockutil_available; then
        echo "0/1"
        return
    fi

    local passed=0
    local total=${#DOCK_APPS[@]}

    for app in "${DOCK_APPS[@]}"; do
        if check_dock_item "$app"; then
            ((passed++))
            if [[ "$VERBOSE" == "true" ]]; then
                log_success "$app in Dock"
            fi
        else
            if [[ "$VERBOSE" == "true" ]]; then
                log_error "$app not in Dock"
            fi
        fi
    done

    echo "$passed/$total"
}

# =============================================================================
# Ensure Functions
# =============================================================================

# Add a single app to the Dock if missing
# Usage: ensure_dock_item "Alacritty" "/Applications/Alacritty.app"
ensure_dock_item() {
    local app="$1"
    local app_path="$2"

    if check_dock_item "$app"; then
        log_success "$app in Dock"
        return 0
    fi

    if [[ ! -d "$app_path" ]]; then
        log_warning "$app — app not installed at $app_path"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "$app — would add to Dock"
        return 0
    fi

    log_warning "$app not in Dock"
    log_action "Adding..."

    if dockutil --add "$app_path" --no-restart &>/dev/null; then
        log_success "$app added to Dock"
        return 0
    else
        log_warning "$app — failed to add to Dock (optional)"
        return 0
    fi
}

# Ensure all required apps are in the Dock
ensure_dock() {
    if ! check_dockutil_available; then
        log_warning "dockutil not installed — skipping Dock setup"
        return 0
    fi

    local changed=false

    for app in "${DOCK_APPS[@]}"; do
        if ! check_dock_item "$app"; then
            changed=true
        fi
        ensure_dock_item "$app" "/Applications/${app}.app"
    done

    # Restart Dock once if changes were made
    if [[ "$changed" == "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        killall Dock 2>/dev/null || true
    fi
}
