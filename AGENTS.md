# Agent Instructions for harmonyjs/dotfiles

You are maintaining a dotfiles repository that uses GNU Stow for symlink management on macOS. The setup uses Catppuccin Latte theme across all configurations.

## Repository Context
- Configuration files are stored in repository root and symlinked to home directory via `stow -v -t ~ --no-folding .`
- Required stow flags: `-t ~` (target home directory), `--no-folding` (preserve runtime directories), `-v` (verbose)
- `.stow-local-ignore` controls which files should NOT be symlinked
- Machine-specific settings use `*.local` pattern (`.zshrc.local`, `*.local.json`) - never symlinked
- Always verify changes with `just check` (or `./scripts/check`)
- Maintain macOS compatibility with Homebrew-installed dependencies

## Scenario 1: Adding New Dotfile

If a user asks you to add a new dotfile, you must ensure:

1. **Validate Environment**: Confirm you're in the dotfiles directory by checking for presence of existing dotfiles
2. **File Naming**: Create the new file with proper dot prefix naming convention in repository root
3. **Machine-Specific Check**: Determine if this should be a machine-specific file (use `.local` suffix if needed)
4. **Stow Configuration**: Check if the new file should be excluded from symlinking by consulting `.stow-local-ignore` patterns
5. **Conflict Prevention**: Test that stow can create the symlink without conflicts before applying changes
6. **Symlink Creation**: Use `stow -v -t ~ --no-folding .` to create the symlink with required flags
7. **Symlink Validation**: Confirm the symlink was created with relative path (not absolute) and points to dotfiles directory
8. **System Integrity**: Run the verification script to ensure the addition didn't break existing functionality
9. **Documentation Update**: Add the new file to the README.md "What's Included" section with brief description

## Scenario 2: Updating Existing Configuration

When a user requests changes to any configuration file, you must:

1. **Backup Creation**: Always create a timestamped backup of the current configuration before making changes
2. **Configuration Type**: Identify whether you're modifying tmux (.config/tmux/tmux.conf), alacritty (.config/alacritty/alacritty.toml), or shell (.zshrc, .zsh_aliases) configuration
3. **Machine-Specific Preservation**: Never modify `.zshrc.local` or `*.local.json` files - these are machine-specific and not version controlled
4. **Theme Preservation**: Maintain the Catppuccin Latte theme consistency while making requested changes
5. **Syntax Validation**: Test that the modified configuration has valid syntax for the specific tool
6. **Live Reload**: Apply configuration changes to any currently running sessions of the affected application
7. **Comprehensive Testing**: Run the full verification suite to confirm all functionality remains intact
8. **Documentation Sync**: Update relevant documentation if changes affect user-visible behavior or keybindings

## Scenario 3: Debugging Configuration Issues

When troubleshooting problems with the dotfiles setup, you should:

1. **Diagnostic Assessment**: Run the verification script first and identify which specific checks are failing
2. **Symlink Integrity**: Verify all symlinks are pointing correctly to files in the dotfiles directory
3. **Path Type Validation**: Check if symlinks use relative paths (correct) vs absolute paths (incorrect) - check script warns about this
4. **Broken Link Detection**: Identify any broken symlinks in the home directory that need attention
5. **Stow Status Check**: Examine stow's simulation output for conflicts, warnings, or other issues
6. **Symlink Recovery**: If symlinks are corrupted or missing, use `stow -D -v -t ~ --no-folding . && stow -v -t ~ --no-folding .` to recreate
7. **Absolute Path Fix**: If absolute symlinks found, remove and recreate with correct stow flags to generate relative paths
8. **Configuration Restoration**: If configurations are broken, restore from the most recent timestamped backup
9. **Final Validation**: Always conclude debugging by running the verification script to confirm resolution

## Scenario 4: Fresh macOS Bootstrap

When the user is setting up a brand-new Mac (or after a clean install) and asks you to bring the environment up, use `./scripts/bootstrap` (`just bootstrap <git-url>`). This is the only path that starts from a blank macOS install — `just init` assumes Homebrew, git, SSH and 1Password already exist.

**Mental model — the chicken-and-egg:** pushing dotfiles, signing commits, and the converged SSH `origin` remote all require the 1Password SSH agent, which in turn requires 1Password.app installed, signed-in, with the developer toggles enabled. So bootstrap has one **manual, user-gated step** for 1Password. It is now **conditional**: when `ssh_ready` (`scripts/lib/git.sh`) already passes — agent holds a key *and* GitHub authenticates it — the gate is skipped entirely. This is by design; keep the gate, but keep it conditional. (Note: `.private` currently clones over the **HTTPS** URLs pinned in `.gitmodules`, so submodule init does not itself depend on the SSH gate — flagged for review.)

**Order of operations (do not reorder):**
1. sudo keep-alive → 2. Xcode CLT → 3. Homebrew → 4. `git clone` over **HTTPS**, then source `lib/git.sh` and print a **state summary** → 5. `brew install --cask 1password-cli` (CLI only; desktop is dmg) → 6. **conditional manual gate**: skipped when `ssh_ready` already passes; otherwise the user installs 1Password.app from `1password.com/downloads`, signs in, enables SSH agent + git signing, adds key to GitHub (the prompt reads from `/dev/tty` so it survives `curl | bash`, then re-verifies `ssh_ready`) → 7. **no-op** — the HTTPS → SSH switch is owned by `ensure_ssh_remote` and runs inside `scripts/init` → 8. `git submodule update --init --recursive` → 9. hand off to `scripts/init` (deps, symlinks, plugins, **and `ensure_ssh_remote`**) → 10. hand off to `scripts/post-install`.

**Steps you must not invent or skip:**
- Do not pre-install 1Password desktop via `brew install --cask 1password`. This repo's policy is desktop GUI apps come from official dmg, not brew cask. The bootstrap script reflects this.
- The readiness check is `ssh_ready` (`scripts/lib/git.sh`): the agent holds a key (`ssh-add -l`) **and** GitHub authenticates it. This is strictly stronger than the old bare socket `-S` test, which returned true even when the agent held no identities (the live-socket / empty-agent trap). The `2BUA8C4S2C` socket-path prefix is 1Password Inc's Apple Team ID — stable across Macs, a documented contract, safe to hardcode (see `OP_SSH_AGENT_SOCK`).
- Do not write to `.gitconfig` or any other identity-bearing file in this scenario — those live in `.private/` and arrive when submodules initialize.
- Do not call `chsh` — Andrey uses the system `/bin/zsh` deliberately. There is no `brew "zsh"` entry.

**`scripts/post-install` is one-shot, idempotent, separate from `scripts/init`:**
- `scripts/init` does work that should re-converge on every run (symlinks, brew bundle, plugins).
- `scripts/post-install` does work that only needs to happen once per machine and would be wrong to repeat (write `/etc/pam.d/sudo_local`, seed `~/.ssh/known_hosts`). It is **sudo-aware**: under `bootstrap -y` / no TTY it skips the root-only TouchID-for-sudo write with a note (`run sudo ./scripts/post-install`) instead of hanging or dying. It no longer touches the machine hostname — that was a one-off OS personalisation, not a dotfiles concern. Bootstrap calls both, but on subsequent machine maintenance only `init` is re-run.
- **Remote SSH (Cloudflare):** `scripts/lib/remote-ssh.sh#ensure_remote_ssh` (called by `post-install`) reproduces the cloudflared tunnel daemon, `10.99.99.1` loopback alias, and sshd Cloudflare-CA trust from `.private/cloudflared/` + 1Password (item `cloudflared-macbook-ssh`, vault `ssh`). `check` verifies it. Restore needs op-as-user (no `sudo` prefix).

**Modes:** `scripts/bootstrap` supports `--dry-run` (preview every step, change nothing — the repo must already be cloned for the repo-dependent steps to preview; on a truly blank machine it previews up to the clone and exits) and `-y/--yes` (unattended: never block on a prompt — the 1Password gate and the sudo-gated TouchID tweak are skipped with a note). Flags and the positional URL can be combined. Idempotency is structural: every mutating step detects "already done" and skips.

**Forking the repo:** `scripts/bootstrap` takes the repo URL as a positional arg (parsed alongside flags), falls back to `$DOTFILES_REPO`, then to auto-detection from `git remote get-url origin` on an existing clone. The HTTPS → SSH switch is derived from whatever URL the user supplies — do not introduce a hardcoded `harmonyjs/dotfiles` path anywhere.

## Critical Requirements
- **Theme Consistency**: Never modify color schemes away from Catppuccin Latte
- **macOS Compatibility**: All changes must work on macOS with Homebrew dependencies
- **Verification Mandatory**: Every change must pass `just check`
- **Backup Safety**: Always create backups before modifying existing configurations
- **Stow Flags**: Always use `-v -t ~ --no-folding` flags with stow commands
- **Symlink Paths**: Ensure symlinks use relative paths, never absolute paths
- **Machine-Specific Files**: Preserve `*.local` pattern files (.zshrc.local, *.local.json) - never modify or version control them
- **Stow Ignore Respect**: Never modify `.stow-local-ignore` without understanding symlink implications
- **Private Submodule Priority**: When modifying stow configuration, maintain priority order: public first, then private (`.private/` is stowed separately)
- **Optional Submodules**: `.private/` submodule is optional - scripts must handle its absence gracefully
- **Brew cask policy**: Homebrew is for CLIs, fonts, headless system utilities (raycast, alacritty, bluesnooze, 1password-cli, clickhouse). Desktop GUI apps — editors/IDEs (Claude, VS Code, JetBrains, Android Studio), messengers (Discord, Telegram), productivity (Notion, Figma), browsers, 1Password **desktop**, office suites — are installed from official `.dmg`. Do not propose `cask "<gui-app>"` additions to `Brewfile` for those categories.
- **Public vs private repo split**: This is a **public** repo intended for others to fork. Anything personal (hostnames, public keys, identity-bearing configs, service credentials, machine-specific paths) goes in the `.private/` submodule — never directly in the public tree. When in doubt about a file's classification, ask before staging.
