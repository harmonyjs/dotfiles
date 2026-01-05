#!/usr/bin/env bash
# submodules.sh - Git submodule management functions
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# Submodule Definitions
# =============================================================================

# Required submodules (will be initialized automatically)
REQUIRED_SUBMODULES=(.claude)

# Optional submodules (may require special access)
OPTIONAL_SUBMODULES=(.private)

# =============================================================================
# Submodule Check Functions
# =============================================================================

# Check if a submodule is initialized
# A submodule is initialized if its directory exists and is not empty
is_submodule_initialized() {
    local submodule="$1"
    local path="$DOTFILES_DIR/$submodule"

    # Check if directory exists and has files (not just .git)
    [[ -d "$path" ]] && [[ -n "$(ls -A "$path" 2>/dev/null)" ]]
}

# Check if a submodule exists in .gitmodules
is_submodule_defined() {
    local submodule="$1"
    grep -q "path = $submodule" "$DOTFILES_DIR/.gitmodules" 2>/dev/null
}

# Get status of a submodule
get_submodule_status() {
    local submodule="$1"

    if ! is_submodule_defined "$submodule"; then
        echo "not-defined"
    elif is_submodule_initialized "$submodule"; then
        echo "initialized"
    else
        echo "not-initialized"
    fi
}

# =============================================================================
# Submodule Initialization Functions
# =============================================================================

# Initialize a single submodule
init_submodule() {
    local submodule="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    cd "$DOTFILES_DIR" || return 1

    git submodule update --init "$submodule" 2>&1 | while read -r line; do
        log_verbose "$line"
    done

    is_submodule_initialized "$submodule"
}

# Ensure a required submodule is initialized
ensure_submodule() {
    local submodule="$1"
    local is_optional="${2:-false}"

    local status
    status=$(get_submodule_status "$submodule")

    case "$status" in
        "initialized")
            log_success "$submodule"
            return 0
            ;;
        "not-initialized")
            if [[ "$DRY_RUN" == "true" ]]; then
                log_warning "$submodule — would initialize"
                return 0
            fi

            log_warning "$submodule not initialized"
            log_action "Initializing..."

            if init_submodule "$submodule"; then
                log_success "$submodule"
                return 0
            else
                if [[ "$is_optional" == "true" ]]; then
                    log_info "$submodule — not initialized (optional)"
                    return 0
                else
                    log_error "$submodule — initialization failed"
                    return 1
                fi
            fi
            ;;
        "not-defined")
            log_info "$submodule — not defined in .gitmodules"
            return 0
            ;;
    esac
}

# Initialize all submodules
ensure_all_submodules() {
    local failed=0

    # Required submodules
    for submodule in "${REQUIRED_SUBMODULES[@]}"; do
        if ! ensure_submodule "$submodule" false; then
            ((failed++))
        fi
    done

    # Optional submodules
    for submodule in "${OPTIONAL_SUBMODULES[@]}"; do
        if is_submodule_defined "$submodule"; then
            ensure_submodule "$submodule" true
        fi
    done

    return $failed
}

# =============================================================================
# Submodule Update Functions
# =============================================================================

# Update a single submodule
update_submodule() {
    local submodule="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    cd "$DOTFILES_DIR" || return 1

    git submodule update --remote "$submodule" 2>&1 | while read -r line; do
        log_verbose "$line"
    done
}

# Update all submodules
update_all_submodules() {
    local updated=0

    for submodule in "${REQUIRED_SUBMODULES[@]}" "${OPTIONAL_SUBMODULES[@]}"; do
        if is_submodule_initialized "$submodule"; then
            # Get current commit
            local before after
            before=$(cd "$DOTFILES_DIR/$submodule" && git rev-parse HEAD 2>/dev/null)

            update_submodule "$submodule"

            after=$(cd "$DOTFILES_DIR/$submodule" && git rev-parse HEAD 2>/dev/null)

            if [[ "$before" != "$after" ]]; then
                local count
                count=$(cd "$DOTFILES_DIR/$submodule" && git rev-list --count "$before".."$after" 2>/dev/null || echo "?")
                log_success "$submodule updated ($count commits)"
                ((updated++))
            else
                log_success "$submodule up to date"
            fi
        fi
    done

    return $updated
}

# =============================================================================
# Check Functions (for check script)
# =============================================================================

# Check all submodules and return count
check_all_submodules() {
    local total=0
    local passed=0

    for submodule in "${REQUIRED_SUBMODULES[@]}"; do
        ((total++))
        if is_submodule_initialized "$submodule"; then
            ((passed++))
            if [[ "$VERBOSE" == "true" ]]; then
                log_success "$submodule"
            fi
        else
            log_error "$submodule — not initialized"
        fi
    done

    echo "$passed/$total"
}
