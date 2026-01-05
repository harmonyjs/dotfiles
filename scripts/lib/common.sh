#!/usr/bin/env bash
# common.sh - Base functions for dotfiles scripts
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# Colors
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m' # No Color

# =============================================================================
# Global Variables
# =============================================================================

DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Determine dotfiles directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Argument Parsing
# =============================================================================

parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose|-v)
                VERBOSE=true
                ;;
            --dry-run|-n)
                DRY_RUN=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
        esac
    done
}

# =============================================================================
# Logging Functions
# =============================================================================

# Print a success message: ✓ message (to stderr for check functions)
log_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

# Print a warning message: ⚠ message
log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Print an error message: ✗ message (to stderr for check functions)
log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Print an info message: ℹ message
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Print a section header: === Title ===
log_section() {
    echo
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Print indented action: → message
log_action() {
    echo -e "  ${DIM}→${NC} $1"
}

# Print verbose message (only if VERBOSE=true)
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${DIM}  $1${NC}"
    fi
}

# =============================================================================
# Action Runner
# =============================================================================

# Run an action with DRY_RUN support
# Usage: run_action "description" "check_command" "action_command"
# - If check_command succeeds → already done, skip
# - If DRY_RUN → show what would be done
# - Otherwise → execute action_command
run_action() {
    local description="$1"
    local check_cmd="$2"
    local action_cmd="$3"

    # Check if already done
    if eval "$check_cmd" &>/dev/null; then
        log_success "$description"
        return 0
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "$description — would perform"
        return 0
    fi

    # Execute action
    log_warning "$description"
    log_action "Performing..."

    if eval "$action_cmd"; then
        log_success "$description"
        return 0
    else
        log_error "$description — failed"
        return 1
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Check if we're in the dotfiles directory
check_dotfiles_dir() {
    if [[ ! -f "$DOTFILES_DIR/.tmux.conf" ]] || [[ ! -f "$DOTFILES_DIR/.zshrc" ]]; then
        log_error "Not in dotfiles directory"
        echo "Please run this script from the dotfiles directory"
        exit 1
    fi
}

# Print a horizontal separator
print_separator() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Get version of a command
get_version() {
    local cmd="$1"
    case "$cmd" in
        git)
            git --version 2>/dev/null | awk '{print $3}'
            ;;
        tmux)
            tmux -V 2>/dev/null | awk '{print $2}'
            ;;
        stow)
            stow --version 2>/dev/null | head -1 | awk '{print $NF}'
            ;;
        starship)
            starship --version 2>/dev/null | head -1 | awk '{print $2}'
            ;;
        brew)
            brew --version 2>/dev/null | head -1 | awk '{print $2}'
            ;;
        *)
            echo "unknown"
            ;;
    esac
}
