#!/usr/bin/env bash
# git.sh - Git remote / SSH-readiness helpers
# This file should be sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# =============================================================================
# 1Password SSH agent
# =============================================================================

# The SSH agent socket exposed by 1Password.app. The "2BUA8C4S2C" prefix is
# 1Password Inc's Apple Team ID — stable across Macs and a documented contract,
# so it can be hardcoded. Overridable via env for non-standard setups.
OP_SSH_AGENT_SOCK="${OP_SSH_AGENT_SOCK:-$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"

# True when the 1Password agent is unlocked AND exposing at least one key.
# `ssh-add -l` exits non-zero both when the agent is unreachable and when it
# holds no identities — either way, not ready.
op_agent_has_keys() {
    [[ -S "$OP_SSH_AGENT_SOCK" ]] || return 1
    SSH_AUTH_SOCK="$OP_SSH_AGENT_SOCK" ssh-add -l &>/dev/null
}

# True when GitHub accepts one of the agent's keys. GitHub always exits non-zero
# on `ssh -T` (it grants no shell), so we match the success banner instead of
# the exit code. The probe is deliberately side-effect-free — no known_hosts
# writes (UserKnownHostsFile=/dev/null), no prompts (BatchMode), short timeout —
# so scripts/check can call it without violating its read-only contract.
github_ssh_auth_ok() {
    SSH_AUTH_SOCK="$OP_SSH_AGENT_SOCK" ssh \
        -o BatchMode=yes -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -T git@github.com 2>&1 | grep -q "successfully authenticated"
}

# Full readiness: agent holds a key AND GitHub authenticates with it. The
# short-circuit means no network round-trip when the agent is empty/locked.
ssh_ready() {
    op_agent_has_keys && github_ssh_auth_ok
}

# =============================================================================
# Origin remote convergence
# =============================================================================

# Converge the dotfiles origin remote to SSH — but only once SSH actually
# authenticates, so we never leave behind a remote that can't push. Idempotent
# and safe to re-run; never downgrades an existing SSH remote. Honors DRY_RUN.
ensure_ssh_remote() {
    local dir="${DOTFILES_DIR:?DOTFILES_DIR must be set}"
    local url
    url="$(git -C "$dir" remote get-url origin 2>/dev/null)" || {
        log_error "Git remote — no 'origin' remote found"
        return 1
    }

    # Already on SSH (or some non-GitHub-HTTPS URL) — leave it alone.
    if [[ "$url" != https://github.com/* ]]; then
        log_success "Git remote — origin already on SSH"
        return 0
    fi

    # HTTPS, but SSH isn't usable yet: a switch now would break push/fetch.
    if ! ssh_ready; then
        log_warning "Git remote — origin on HTTPS; SSH not ready (unlock 1Password, ensure the key is on GitHub) — leaving as-is"
        return 0
    fi

    local path ssh_url
    path="${url#https://github.com/}"
    path="${path%.git}.git"
    ssh_url="git@github.com:${path}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Git remote — origin → $ssh_url (would switch)"
        return 0
    fi

    git -C "$dir" remote set-url origin "$ssh_url"
    log_success "Git remote — origin → $ssh_url"
}

# =============================================================================
# Check Function (for check script)
# =============================================================================

# Read-only remote check. Echoes "passed/total" on stdout; all human-readable
# output goes to stderr so the captured result stays clean.
#   - origin on SSH                     → pass (converged)
#   - origin on HTTPS, SSH not ready    → pass (legitimately blocked on 1Password)
#   - origin on HTTPS, SSH IS ready     → fail (actionable drift: init would switch)
check_ssh_remote() {
    local dir="${DOTFILES_DIR:?}"
    local url
    url="$(git -C "$dir" remote get-url origin 2>/dev/null)"

    if [[ "$url" != https://github.com/* ]]; then
        [[ "$VERBOSE" == "true" ]] && log_success "origin on SSH"
        echo "1/1"
        return 0
    fi

    if ssh_ready; then
        log_error "origin on HTTPS but SSH is ready — run ./scripts/init to switch"
        echo "0/1"
    else
        [[ "$VERBOSE" == "true" ]] && \
            printf '  origin on HTTPS; SSH not ready yet (unlock 1Password, then run ./scripts/init)\n' >&2
        echo "1/1"
    fi
}
