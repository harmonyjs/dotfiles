# Reproducible cloudflared / WARP-SSH setup (Mac-side) — Design

Date: 2026-05-31
Status: Approved (design); pending implementation plan

## Goal

Make the cloudflared + Cloudflare **Access for Infrastructure** SSH setup on this MacBook
**reproducible and idempotent from the dotfiles repo**, so a fresh/rebuilt Mac can rejoin
without manual reconfiguration. Floor: a single idempotent script. Target: wired into the
dotfiles lifecycle (`post-install` + `check`).

## Scope

**In scope** — the Mac-local/system layer:

- cloudflared install (already in `Brewfile`), tunnel config + LaunchDaemon
- loopback alias `10.99.99.1` + LaunchDaemon
- sshd trust of the Cloudflare SSH CA
- Remote Login (SSH server) enablement
- tunnel secret restore from 1Password via `op`
- verification + dotfiles lifecycle integration

**Out of scope:**

- **Cloudflare account objects** (tunnel, DNS record, Access apps, Target, Infra app,
  device-enrollment policy, split-tunnel, SSH CA). They live server-side and persist; we
  reuse them. Not codified as Terraform (deliberate — see "Reproducibility scope" decision).
- **iPhone client** (Prompt 3 / WARP enrollment). Client-side; nothing to store in dotfiles.
- The laptop `~/.ssh/config` block for `ssh.vavilov.team` — already committed in `.private`.

## Background: what the setup is

Named tunnel `macbook-ssh` (id `510cce4d-b5d4-4d47-a232-cd85113a2be1`) with **two access paths**:

1. **Public hostname** `ssh.vavilov.team` → cloudflared ingress `ssh://localhost:22`, protected
   by a Cloudflare Access self-hosted app. Used from laptops via
   `ProxyCommand cloudflared access ssh`.
2. **WARP → Access for Infrastructure** for the iPhone (no `cloudflared` on iOS): native SSH
   client connects to `10.99.99.1` over WARP; Cloudflare injects a ~3-min short-lived SSH cert.
   sshd trusts the Cloudflare SSH CA. cloudflared proxies `10.99.99.1` → `localhost:22`; the IP
   is a loopback alias on the Mac (colocated cloudflared dials it locally). CIDR route
   `10.99.99.1/32` → tunnel; WARP device profile is Include-mode with `10.99.99.1/32`.

Both paths share one cloudflared daemon and one sshd.

## Reproducibility scope decision

**Mac-side only.** Cloudflare account objects persist server-side and are reused on a new Mac.
The only server-bound secret needed locally is the tunnel credentials file (`<id>.json`);
`cert.pem` can be regenerated via `cloudflared tunnel login`. We restore both from 1Password.
Full Cloudflare-as-code (Terraform) is explicitly deferred — not needed unless the account is lost.

## File layout

| Artifact | Location | Secret? |
|----------|----------|---------|
| identity values: `TUNNEL_ID`, `ALIAS_IP=10.99.99.1`, `HOSTNAME=ssh.vavilov.team`, `OP_CERT_REF`, `OP_CREDS_REF` | `.private/cloudflared/remote-ssh.env` | no |
| `cloudflared` tunnel config | `.private/cloudflared/config.yml` | no |
| cloudflared daemon plist | `.private/cloudflared/com.cloudflare.cloudflared.plist` | no |
| loopback-alias daemon plist | `.private/cloudflared/com.local.lo0-alias.plist` | no |
| Cloudflare SSH CA public key | `.private/cloudflared/cloudflare-ssh-ca.pub` | no (public) |
| sshd CA-trust drop-in | `.private/cloudflared/sshd_config.d/100-cloudflare-ca.conf` | no |
| `cert.pem` + `<id>.json` | **1Password** (item `cloudflared-macbook-ssh`, vault `ssh`) | **yes** |
| copier / installer | `scripts/lib/remote-ssh.sh` (`ensure_remote_ssh`) | — |

Files are stored **static** (chosen over templating): the script copies them verbatim into
system locations. `tunnel-id` is duplicated across `config.yml`, the creds filename, and
`remote-ssh.env` — accepted trade-off for git-visible, diffable files.

### Static file contents (as built)

- `config.yml`:
  ```yaml
  tunnel: 510cce4d-b5d4-4d47-a232-cd85113a2be1
  credentials-file: /etc/cloudflared/510cce4d-b5d4-4d47-a232-cd85113a2be1.json

  warp-routing:
    enabled: true

  ingress:
    - hostname: ssh.vavilov.team
      service: ssh://localhost:22
    - service: http_status:404
  ```
- `com.cloudflare.cloudflared.plist`: runs
  `/opt/homebrew/bin/cloudflared --no-autoupdate --config /etc/cloudflared/config.yml tunnel run`,
  `RunAtLoad` + `KeepAlive`, logs to `/var/log/cloudflared{,.err}.log`.
- `com.local.lo0-alias.plist`: runs
  `/sbin/ifconfig lo0 alias 10.99.99.1 netmask 255.255.255.255`, `RunAtLoad`.
- `cloudflare-ssh-ca.pub`: `ecdsa-sha2-nistp256 AAAAE2VjZHNh…open-ssh-ca@cloudflareaccess.org`.
- `sshd_config.d/100-cloudflare-ca.conf`:
  ```
  PubkeyAuthentication yes
  TrustedUserCAKeys /etc/ssh/ca.pub
  ```

### 1Password item

- Vault `ssh`, item `cloudflared-macbook-ssh`, two file/document fields:
  `cert.pem` and `credentials.json`.
- `remote-ssh.env` references:
  - `OP_CERT_REF="op://ssh/cloudflared-macbook-ssh/cert.pem"`
  - `OP_CREDS_REF="op://ssh/cloudflared-macbook-ssh/credentials.json"`
- Created once, by hand (like the SSH CA generation). Exact `op` commands in the plan.

## `ensure_remote_ssh()` behavior

Lives in `scripts/lib/remote-ssh.sh`, sourced/called from `scripts/post-install`. Follows the
existing post-install conventions: `set -euo pipefail`, `log_section`/`log_*`, `DRY_RUN`
handling, `can_sudo` graceful-skip, idempotent (overwrite-in-place + daemon reload).

1. **Guard** — if `.private/cloudflared/remote-ssh.env` is absent → log + skip (this Mac is not
   configured for the tunnel). Source it otherwise.
2. **Tooling** — require `cloudflared` and `op`; if `op` is not signed in, log + skip the
   secret-dependent steps (do not hang). Mirrors the 1Password-gated pattern already in the repo.
3. **Remote Login** — enable if off (`systemsetup -setremotelogin on`, sudo-aware; fall back to a
   note pointing at System Settings when sudo is unavailable, per existing pattern).
4. **Secrets** — `op read "$OP_CERT_REF"` → `~/.cloudflared/cert.pem` (0600);
   `op read "$OP_CREDS_REF"` → `/etc/cloudflared/<TUNNEL_ID>.json` (root:wheel, 0600).
5. **cloudflared** — install `.private/cloudflared/config.yml` → `/etc/cloudflared/config.yml`;
   install daemon plist → `/Library/LaunchDaemons/`; `launchctl bootout`+`bootstrap`+`enable`.
6. **Loopback alias** — install alias plist → `/Library/LaunchDaemons/`; bootstrap; also bring the
   alias up immediately (`ifconfig lo0 alias …`).
7. **sshd CA trust** — install `cloudflare-ssh-ca.pub` → `/etc/ssh/ca.pub` (root:wheel, 0644);
   install drop-in → `/etc/ssh/sshd_config.d/100-cloudflare-ca.conf`; remove the legacy in-place
   `# cloudflare-access-for-infrastructure` block from `/etc/ssh/sshd_config` if present
   (migration to the drop-in). Validate with `sshd -t`.
8. **Restart + verify** — `launchctl kickstart -k` both daemons; print verification (see below).

The current host was bootstrapped manually; this function reproduces that exact end state and is
the single source applied on a fresh Mac.

## Idempotency

Every write is overwrite-in-place; every daemon load is `bootout || true` then `bootstrap`. Re-running
converges to the same state with no duplicate launchd jobs and no appended-config drift (drop-in is
replaced, not appended). Safe to run on every `post-install`.

## Verification (`scripts/check`)

New read-only section "Remote SSH (Cloudflare)":

- `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` loaded and `cloudflared … tunnel run` running
- `lo0` has alias `10.99.99.1`
- `/etc/ssh/ca.pub` present and `TrustedUserCAKeys` effective (drop-in present)
- `cloudflared tunnel route ip list` shows `10.99.99.1/32` (best-effort; needs cert.pem)

Manual end-to-end (documented, not automated): from iPhone over WARP `ssh andreyvavilov@10.99.99.1`;
from laptop `ssh ssh.vavilov.team`.

## Security

- `cert.pem` and `<id>.json` never enter git — only 1Password. `remote-ssh.env` holds `op://`
  references, not secrets.
- Credentials file is root:wheel 0600 in `/etc/cloudflared`; `ca.pub` is a public key (0644).
- `.private` is a private submodule (`harmonyjs/dotfiles-private`); even so, no live secrets land there.

## One-time manual prerequisite

Create the 1Password item with `cert.pem` and `credentials.json` (exact `op` upload commands in the
plan). After that, on any fresh Mac: `op signin` → `./scripts/post-install` reproduces the setup.

## Decisions resolved

- Reproducibility scope: **Mac-side only** (Cloudflare objects reused server-side).
- Secret storage: **1Password via `op`**.
- System files: **stored static** in `.private/cloudflared/` (copied, not templated).
- Integration: **`post-install`** (+ `check`), with the core as one idempotent function.
