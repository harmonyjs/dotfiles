#!/usr/bin/env bash
# memory.sh - Claude Code auto-memory linking (repo-backed dir symlinks)
# This file should be sourced, not executed directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# Encode an absolute project path to Claude Code's project-id (slash & dot -> dash).
memory_project_id() {
    local path="${1%/}"
    printf '%s' "$path" | sed 's#[./]#-#g'
}

# Normalize one project's memory dir to a repo-backed directory symlink.
# Handles: already-linked (no-op), real-only, per-file symlinks, mixed, absent.
link_memory_id() {
    local id="$1"
    local home_mem="$HOME/.claude/projects/$id/memory"
    local repo_mem="$DOTFILES_DIR/.claude/projects/$id/memory"

    # Repo target must exist (empty dirs are git-ignored until a file lands).
    mkdir -p "$repo_mem"

    # Already a symlink.
    if [[ -L "$home_mem" ]]; then
        if [[ "$(readlink "$home_mem")" == "$repo_mem" ]]; then
            return 0
        fi
        rm -f "$home_mem"
        ln -s "$repo_mem" "$home_mem"
        return 0
    fi

    # Real directory present (real-only / per-file links / mixed).
    if [[ -d "$home_mem" ]]; then
        # Memory dirs are flat (atom *.md + MEMORY.md). Any subdirectory OR hidden
        # entry is non-memory state (an audit/scratch dir, a stray .DS_Store) that
        # the flat normalization below cannot handle: the migration loop globs
        # "$home_mem"/* (dotglob off, so it skips hidden entries), would move the
        # loose files, then fail to rmdir the survivor — a half-migrated real dir.
        # Refuse atomically; move the offending entry out and re-run.
        if [[ -n "$(find "$home_mem" -mindepth 1 -maxdepth 1 \( -type d -o -name '.*' \) 2>/dev/null)" ]]; then
            log_warning "memory: $home_mem has a subdirectory or hidden entry (non-flat) — skipped; move it out and re-run"
            return 1
        fi
        local f base has_real=false
        for f in "$home_mem"/*; do
            [[ -e "$f" || -L "$f" ]] || continue
            if [[ -f "$f" && ! -L "$f" ]]; then has_real=true; break; fi
        done
        if [[ "$has_real" == true ]]; then
            cp -R "$home_mem" "$home_mem.backup.$(date +%Y%m%d-%H%M%S)"
        fi

        for f in "$home_mem"/*; do
            [[ -e "$f" || -L "$f" ]] || continue
            base="$(basename "$f")"
            if [[ -L "$f" ]]; then
                rm -f "$f"                                  # repo already holds the target
            elif [[ -f "$f" ]]; then
                if [[ ! -e "$repo_mem/$base" ]]; then
                    mv "$f" "$repo_mem/$base"               # capture local-only file
                elif cmp -s "$f" "$repo_mem/$base"; then
                    rm -f "$f"                              # identical → repo wins
                else
                    local stash="$HOME/.claude/.memory-conflicts/$id"
                    mkdir -p "$stash"
                    mv "$f" "$stash/$base.$(date +%Y%m%d-%H%M%S)"
                    log_warning "memory conflict: $id/$base — kept repo, stashed ~ copy in $stash"
                fi
            fi
        done

        if ! rmdir "$home_mem" 2>/dev/null; then
            log_warning "memory: $home_mem not empty after migration — left as-is"
            return 1
        fi
        ln -s "$repo_mem" "$home_mem"
        return 0
    fi

    # Nothing in ~ yet → create parent and link.
    mkdir -p "$(dirname "$home_mem")"
    ln -s "$repo_mem" "$home_mem"
    return 0
}

# Convenience wrapper: link by project path (used by the SessionStart hook).
link_memory_project() {
    link_memory_id "$(memory_project_id "$1")"
}

# Link every known project's memory dir (union of repo-known and home-known ids).
link_memory() {
    local repo_root="$DOTFILES_DIR/.claude/projects"
    local home_root="$HOME/.claude/projects"
    local d id seen=" " failed=0

    _process() {
        local id="$1"
        case "$seen" in *" $id "*) return 0;; esac
        seen+="$id "
        link_memory_id "$id" || failed=1
    }

    if [[ -d "$repo_root" ]]; then
        for d in "$repo_root"/*/memory; do
            [[ -d "$d" ]] || continue
            _process "$(basename "$(dirname "$d")")"
        done
    fi
    if [[ -d "$home_root" ]]; then
        for d in "$home_root"/*/memory; do
            [[ -e "$d" || -L "$d" ]] || continue
            _process "$(basename "$(dirname "$d")")"
        done
    fi

    if [[ "$failed" -eq 0 ]]; then
        log_success "Memory links"
    else
        log_warning "Memory links — some projects need manual attention"
    fi
    return "$failed"
}

# Audit: "passed/total" where a project passes iff its home memory is a repo symlink.
check_memory() {
    local home_root="$HOME/.claude/projects"
    local d id repo_mem total=0 passed=0
    [[ -d "$home_root" ]] || { echo "0/0"; return 0; }
    for d in "$home_root"/*/memory; do
        [[ -e "$d" || -L "$d" ]] || continue
        ((total++)) || true
        id="$(basename "$(dirname "$d")")"
        repo_mem="$DOTFILES_DIR/.claude/projects/$id/memory"
        if [[ -L "$d" && "$(readlink "$d")" == "$repo_mem" ]]; then
            ((passed++)) || true
            [[ "$VERBOSE" == "true" ]] && log_success "memory: $id"
        else
            log_error "memory: $id — not repo-backed (drift)"
        fi
    done
    echo "$passed/$total"
}
