#!/usr/bin/env bash
# symlinks.sh - Symlink management functions
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# Symlink Definitions
# =============================================================================

# Main symlinks created by stow (for verification)
MAIN_SYMLINKS=(
    .zsh_aliases
    .zshrc
    .zshenv
    .zprofile
)

# Config directory symlinks (XDG Base Directory compliant)
CONFIG_SYMLINKS=(
    .config/alacritty/alacritty.toml
    .config/tmux/tmux.conf
    .config/starship.toml
)

# =============================================================================
# Symlink Check Functions
# =============================================================================

# Check if a symlink exists and points to dotfiles
is_symlink_valid() {
    local target="$1"
    local path="$HOME/$target"

    if [[ -L "$path" ]]; then
        local link_target
        link_target=$(readlink "$path")
        [[ "$link_target" == *"dotfiles"* ]]
    else
        return 1
    fi
}

# Check if symlink uses relative path (preferred)
is_symlink_relative() {
    local target="$1"
    local path="$HOME/$target"

    if [[ -L "$path" ]]; then
        local link_target
        link_target=$(readlink "$path")
        [[ "$link_target" != /* ]]
    else
        return 1
    fi
}

# =============================================================================
# Stow Functions
# =============================================================================

# Run stow with standard options
run_stow() {
    local source_dir="${1:-.}"
    local stow_dir="${2:-$DOTFILES_DIR}"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    cd "$stow_dir" || return 1

    if [[ "$source_dir" == "." ]]; then
        # Main dotfiles
        stow -v -t ~ --no-folding . 2>&1 | while read -r line; do
            log_verbose "$line"
        done
    else
        # Subdirectory (like .private)
        stow -v -t ~ --no-folding -d "$source_dir" . 2>&1 | while read -r line; do
            log_verbose "$line"
        done
    fi
}

# Unstow (remove symlinks)
run_unstow() {
    local source_dir="${1:-.}"
    local stow_dir="${2:-$DOTFILES_DIR}"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    cd "$stow_dir" || return 1

    if [[ "$source_dir" == "." ]]; then
        stow -D -v -t ~ --no-folding . 2>&1 | while read -r line; do
            log_verbose "$line"
        done
    else
        stow -D -v -t ~ --no-folding -d "$source_dir" . 2>&1 | while read -r line; do
            log_verbose "$line"
        done
    fi
}

# =============================================================================
# Symlink Creation Functions
# =============================================================================

# Create a single symlink manually
create_symlink() {
    local source="$1"
    local target="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$target")
    mkdir -p "$parent_dir"

    # Remove existing file/symlink if it exists
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        rm -f "$target"
    fi

    ln -sf "$source" "$target"
}

# Ensure starship config symlink (stow may conflict with .claude)
ensure_starship_symlink() {
    local source="$DOTFILES_DIR/.config/starship.toml"
    local target="$HOME/.config/starship.toml"

    if [[ ! -f "$source" ]]; then
        log_info "starship.toml not found in dotfiles"
        return 0
    fi

    if [[ -L "$target" ]]; then
        local link_target
        link_target=$(readlink "$target")
        if [[ "$link_target" == *"dotfiles"* ]]; then
            log_success "Starship config"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Starship config — would create symlink"
        return 0
    fi

    log_warning "Starship config not linked"
    log_action "Creating symlink..."

    mkdir -p "$HOME/.config"
    if create_symlink "$source" "$target"; then
        log_success "Starship config"
        return 0
    else
        log_error "Starship config — failed to create symlink"
        return 1
    fi
}

# =============================================================================
# Main Symlink Functions
# =============================================================================

# Create all main symlinks via stow
ensure_main_symlinks() {
    # Check if already done
    local all_valid=true
    for symlink in "${MAIN_SYMLINKS[@]}"; do
        if ! is_symlink_valid "$symlink"; then
            all_valid=false
            break
        fi
    done

    if [[ "$all_valid" == "true" ]]; then
        log_success "Main symlinks"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Main symlinks — would create via stow"
        return 0
    fi

    log_warning "Main symlinks missing"
    log_action "Creating via stow..."

    if run_stow; then
        log_success "Main symlinks"
        return 0
    else
        log_error "Main symlinks — stow failed"
        return 1
    fi
}

# Create private symlinks via stow (if .private is initialized)
ensure_private_symlinks() {
    local private_dir="$DOTFILES_DIR/.private"

    if [[ ! -d "$private_dir" ]] || [[ -z "$(ls -A "$private_dir" 2>/dev/null)" ]]; then
        log_info "Private symlinks — .private not initialized"
        return 0
    fi

    # Backup existing files that would conflict
    if [[ "$DRY_RUN" != "true" ]]; then
        while IFS= read -r -d '' file; do
            local relpath="${file#$private_dir/}"
            local target="$HOME/$relpath"

            if [[ -f "$target" ]] && [[ ! -L "$target" ]]; then
                log_action "Backing up ~/$relpath..."
                mv "$target" "$target.backup.$(date +%Y%m%d-%H%M%S)"
            fi
        done < <(find "$private_dir" -type f \
            ! -path '*/.git/*' \
            ! -name '.git' \
            ! -name '.gitignore' \
            ! -name '.gitattributes' \
            ! -name '.stow-local-ignore' \
            ! -name 'README.md' \
            ! -name '*.backup.*' \
            ! -path '*/scripts/*' \
            -print0)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Private symlinks — would create via stow"
        return 0
    fi

    log_action "Creating private symlinks..."

    cd "$DOTFILES_DIR" || return 1
    if stow -v -t ~ --no-folding -d .private . 2>&1 | while read -r line; do
        log_verbose "$line"
    done; then
        log_success "Private symlinks"
        return 0
    else
        log_warning "Private symlinks — stow failed (optional)"
        return 0  # Non-fatal
    fi
}

# Ensure all symlinks are created
ensure_all_symlinks() {
    local failed=0

    if ! ensure_main_symlinks; then
        ((failed++))
    fi

    if ! ensure_starship_symlink; then
        ((failed++))
    fi

    ensure_private_symlinks  # Always succeeds (optional)

    return $failed
}

# =============================================================================
# Check Functions (for check script)
# =============================================================================

# Check all symlinks and return count
check_all_symlinks() {
    local total=0
    local passed=0

    # Main symlinks
    for symlink in "${MAIN_SYMLINKS[@]}"; do
        ((total++))
        if is_symlink_valid "$symlink"; then
            ((passed++))
            if [[ "$VERBOSE" == "true" ]]; then
                log_success "$symlink"
            fi
        else
            log_error "$symlink — missing or invalid"
        fi
    done

    # Config symlinks
    for symlink in "${CONFIG_SYMLINKS[@]}"; do
        ((total++))
        if is_symlink_valid "$symlink"; then
            ((passed++))
            if [[ "$VERBOSE" == "true" ]]; then
                log_success "$symlink"
            fi
        else
            log_error "$symlink — missing or invalid"
        fi
    done

    echo "$passed/$total"
}

# Check private symlinks
check_private_symlinks() {
    local private_dir="$DOTFILES_DIR/.private"
    local total=0
    local passed=0

    if [[ ! -d "$private_dir" ]] || [[ -z "$(ls -A "$private_dir" 2>/dev/null)" ]]; then
        echo "0/0"
        return 0
    fi

    while IFS= read -r -d '' file; do
        local relpath="${file#$private_dir/}"
        local target="$HOME/$relpath"
        ((total++))

        if [[ -L "$target" ]]; then
            local link_target
            link_target=$(readlink "$target")
            if [[ "$link_target" == *".private"* ]]; then
                ((passed++))
                if [[ "$VERBOSE" == "true" ]]; then
                    log_success "$relpath"
                fi
            else
                log_error "$relpath — wrong target"
            fi
        else
            log_error "$relpath — not a symlink"
        fi
    done < <(find "$private_dir" -type f \
        ! -path '*/.git/*' \
        ! -name '.git' \
        ! -name '.gitignore' \
        ! -name '.gitattributes' \
        ! -name '.stow-local-ignore' \
        ! -name 'README.md' \
        ! -name '*.backup.*' \
        ! -path '*/scripts/*' \
        ! -path '*/cloudflared/*' \
        -print0)

    echo "$passed/$total"
}
