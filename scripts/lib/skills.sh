#!/usr/bin/env bash
# skills.sh - personal skill catalog linking (repo-backed dir symlink)
# This file should be sourced, not executed directly.
#
# The catalog lives in the .private submodule and is reached through a single
# directory symlink at ~/.agents/skills. Stow cannot own it for two reasons: the
# files are written at runtime by skill self-evolution, so they are born in $HOME
# and have to land in the working tree as they are written, which is the opposite
# of the direction stow works in; and .stow-local-ignore strips every README.md
# but one, which would silently drop the reference material inside the cloudflare
# and turnstile-spin skills. Hence .agents is excluded from stow entirely and
# linked here instead, exactly as memory.sh owns the memory stores.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# Where the catalog lives, and where the harnesses look for it.
skills_repo_dir() { printf '%s' "$DOTFILES_DIR/.private/.agents/skills"; }
skills_home_dir() { printf '%s' "$HOME/.agents/skills"; }

# Normalize ~/.agents/skills to a repo-backed directory symlink.
#
# Cases: already linked (no-op), pointing elsewhere (repointed), absent
# (created), and a real directory (refused). The last one is deliberate. A real
# directory here means two catalogs exist, and the shared layout rules are
# explicit that this is a conflict to inspect rather than grounds to delete one
# side. Refusing costs a warning; guessing costs skills.
link_skills() {
    local repo_dir home_dir parent
    repo_dir="$(skills_repo_dir)"
    home_dir="$(skills_home_dir)"

    if [[ ! -d "$repo_dir" ]]; then
        log_info "Skill catalog — .private not initialized"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -L "$home_dir" ]] && [[ "$(cd "$(dirname "$home_dir")" && realpath "$(readlink "$home_dir")" 2>/dev/null)" == "$repo_dir" ]]; then
            log_success "Skill catalog"
        else
            log_warning "Skill catalog — would link ~/.agents/skills"
        fi
        return 0
    fi

    if [[ -L "$home_dir" ]]; then
        if [[ "$(cd "$(dirname "$home_dir")" && realpath "$(readlink "$home_dir")" 2>/dev/null)" == "$repo_dir" ]]; then
            log_success "Skill catalog"
            return 0
        fi
        log_action "Repointing ~/.agents/skills at the repo..."
        rm -f "$home_dir"
    elif [[ -d "$home_dir" ]]; then
        log_error "Skill catalog — ~/.agents/skills is a real directory, not a link"
        log_info "Two catalogs exist. Compare them and move the keeper into $repo_dir, then re-run."
        return 1
    fi

    parent="$(dirname "$home_dir")"
    mkdir -p "$parent"
    # Absolute target, matching memory.sh. A relative one would read better next
    # to ~/.agents/INSTRUCTIONS.md, but computing it needs realpath
    # --relative-to, and /bin/realpath on macOS is the BSD one, which has no such
    # option - the fallback would fire every single time.
    if ln -s "$repo_dir" "$home_dir"; then
        log_success "Skill catalog"
        return 0
    fi
    log_error "Skill catalog — could not create ~/.agents/skills"
    return 1
}

# Audit: "passed/total" over the single link, so it reads like the other sections.
check_skills() {
    local repo_dir home_dir resolved
    repo_dir="$(skills_repo_dir)"
    home_dir="$(skills_home_dir)"

    if [[ ! -d "$repo_dir" ]]; then
        echo "0/0"
        return 0
    fi

    if [[ ! -L "$home_dir" ]]; then
        if [[ -d "$home_dir" ]]; then
            log_error "Skill catalog — ~/.agents/skills is a real directory (drift)"
        else
            log_error "Skill catalog — ~/.agents/skills missing"
        fi
        echo "0/1"
        return 0
    fi

    resolved="$(cd "$(dirname "$home_dir")" && realpath "$(readlink "$home_dir")" 2>/dev/null)"
    if [[ "$resolved" == "$repo_dir" ]]; then
        [[ "$VERBOSE" == "true" ]] && log_success "skills: $(find -L "$home_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') skills"
        echo "1/1"
    else
        log_error "Skill catalog — ~/.agents/skills points at $resolved"
        echo "0/1"
    fi
    return 0
}
