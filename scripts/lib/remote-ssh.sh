#!/usr/bin/env bash
# remote-ssh.sh - Reproduce the cloudflared / Access-for-Infrastructure SSH setup
# This file should be sourced, not executed directly.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should be sourced, not executed directly"
    exit 1
fi

# Static, non-secret config (not stowed — see .private/.stow-local-ignore).
REMOTE_SSH_SRC="${DOTFILES_DIR:?DOTFILES_DIR must be set}/.private/cloudflared"

# True when sudo runs without prompting (cached ticket or NOPASSWD).
_rssh_can_sudo() { sudo -n true 2>/dev/null; }

# Idempotent: reproduces the Mac-side cloudflared daemon, loopback alias, and sshd
# CA trust from REMOTE_SSH_SRC + secrets in 1Password. Honors DRY_RUN. Skips
# gracefully when the config dir, cloudflared, op-signin, or sudo are unavailable.
ensure_remote_ssh() {
    # 0. Guard: this Mac isn't a tunnel host unless the static config is present.
    if [[ ! -d "$REMOTE_SSH_SRC" ]]; then
        return 0
    fi
    # shellcheck source=/dev/null
    source "$REMOTE_SSH_SRC/remote-ssh.env"
    : "${TUNNEL_ID:?}" "${ALIAS_IP:?}" "${OP_CERT_REF:?}" "${OP_CREDS_REF:?}"

    # 1. Tooling.
    if ! command -v cloudflared &>/dev/null; then
        log_warning "Remote SSH — cloudflared missing (run brew bundle) — skipping"
        return 0
    fi

    # 2. Remote Login (SSH server).
    if systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
        log_success "Remote SSH — Remote Login on"
    elif [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Remote SSH — would enable Remote Login"
    elif _rssh_can_sudo || [[ -t 0 ]]; then
        sudo systemsetup -setremotelogin on && log_success "Remote SSH — Remote Login enabled"
    else
        log_warning "Remote SSH — Remote Login off; enable in System Settings → General → Sharing"
    fi

    # 3. 1Password availability.
    if ! command -v op &>/dev/null || ! op account list &>/dev/null; then
        log_warning "Remote SSH — op not signed in; skipping secret restore + daemon. Run: op signin && ./scripts/post-install"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Remote SSH — would restore secrets from 1Password and install daemons/config"
        return 0
    fi

    # 4. cert.pem (management/check use) into the user dir.
    mkdir -p "$HOME/.cloudflared"
    op read "$OP_CERT_REF" > "$HOME/.cloudflared/cert.pem"
    chmod 600 "$HOME/.cloudflared/cert.pem"

    # Everything below needs root.
    if ! _rssh_can_sudo && [[ ! -t 0 ]]; then
        log_warning "Remote SSH — system install needs sudo (none available unattended) — run: sudo ./scripts/post-install"
        return 0
    fi

    # 5. /etc/cloudflared: config + credentials (secret straight from 1Password to root file).
    sudo install -d -m 755 /etc/cloudflared
    sudo install -m 644 "$REMOTE_SSH_SRC/config.yml" /etc/cloudflared/config.yml
    op read "$OP_CREDS_REF" | sudo tee "/etc/cloudflared/${TUNNEL_ID}.json" >/dev/null
    sudo chown root:wheel "/etc/cloudflared/${TUNNEL_ID}.json"
    sudo chmod 600 "/etc/cloudflared/${TUNNEL_ID}.json"

    # 6. cloudflared LaunchDaemon.
    sudo install -m 644 "$REMOTE_SSH_SRC/com.cloudflare.cloudflared.plist" \
        /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
    sudo launchctl bootout system /Library/LaunchDaemons/com.cloudflare.cloudflared.plist 2>/dev/null || true
    sudo launchctl bootstrap system /Library/LaunchDaemons/com.cloudflare.cloudflared.plist
    sudo launchctl enable system/com.cloudflare.cloudflared

    # 7. Loopback alias now + LaunchDaemon for boot.
    sudo /sbin/ifconfig lo0 alias "$ALIAS_IP" netmask 255.255.255.255 2>/dev/null || true
    sudo install -m 644 "$REMOTE_SSH_SRC/com.local.lo0-alias.plist" \
        /Library/LaunchDaemons/com.local.lo0-alias.plist
    sudo launchctl bootout system /Library/LaunchDaemons/com.local.lo0-alias.plist 2>/dev/null || true
    sudo launchctl bootstrap system /Library/LaunchDaemons/com.local.lo0-alias.plist

    # 8. sshd CA trust via drop-in; migrate away from any legacy in-place block.
    sudo install -m 644 "$REMOTE_SSH_SRC/cloudflare-ssh-ca.pub" /etc/ssh/ca.pub
    sudo install -d -m 755 /etc/ssh/sshd_config.d
    sudo install -m 644 "$REMOTE_SSH_SRC/sshd_config.d/100-cloudflare-ca.conf" \
        /etc/ssh/sshd_config.d/100-cloudflare-ca.conf
    if grep -q '^# cloudflare-access-for-infrastructure' /etc/ssh/sshd_config 2>/dev/null; then
        sudo sed -i '' '/^# cloudflare-access-for-infrastructure$/,/^TrustedUserCAKeys \/etc\/ssh\/ca\.pub$/d' /etc/ssh/sshd_config
    fi
    sudo /usr/sbin/sshd -t && log_success "Remote SSH — sshd config valid"

    log_success "Remote SSH — cloudflared + loopback alias + sshd CA trust reproduced"
}

# Read-only check. Echoes "passed/total" on stdout; human output to stderr.
# Returns "0/0" (skipped) on machines that are not tunnel hosts.
check_remote_ssh() {
    [[ -d "$REMOTE_SSH_SRC" ]] || { echo "0/0"; return 0; }
    # shellcheck source=/dev/null
    source "$REMOTE_SSH_SRC/remote-ssh.env"

    local passed=0 total=3

    if pgrep -fq "cloudflared.*tunnel run"; then
        passed=$((passed + 1)); [[ "$VERBOSE" == "true" ]] && log_success "cloudflared daemon running"
    else
        log_error "cloudflared daemon not running"
    fi

    if /sbin/ifconfig lo0 2>/dev/null | grep -q "${ALIAS_IP:-10.99.99.1}"; then
        passed=$((passed + 1)); [[ "$VERBOSE" == "true" ]] && log_success "loopback alias ${ALIAS_IP} present"
    else
        log_error "loopback alias ${ALIAS_IP} missing"
    fi

    if [[ -f /etc/ssh/ca.pub && -f /etc/ssh/sshd_config.d/100-cloudflare-ca.conf ]]; then
        passed=$((passed + 1)); [[ "$VERBOSE" == "true" ]] && log_success "sshd Cloudflare CA trust present"
    else
        log_error "sshd Cloudflare CA trust missing"
    fi

    echo "${passed}/${total}"
}
