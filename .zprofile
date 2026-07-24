# Login Shell Configuration
# All PATH setup is in .zshenv for universal availability

# Re-assert the Homebrew prefix after /etc/zprofile.
# ═══════════════════════════════════════════════════════════════════
# Login shells source /etc/zprofile *after* ~/.zshenv, and it runs
# `path_helper -s`, which rebuilds PATH from scratch: /etc/paths entries
# (/usr/local/bin:/usr/bin:/bin:...) go first, everything else is appended.
# That silently undoes .zshenv's brew prefix, so /bin wins over
# /opt/homebrew/bin and `#!/usr/bin/env bash` resolves to Apple's
# bash 3.2.57 (frozen at the last GPLv2 release) instead of brew's 5.x.
# The split is invisible interactively — .zshrc fixes it there — but hits
# every login-non-interactive context: agent shells, LaunchAgents, `zsh -l -c`.
# bash 3.2 has no `declare -A`; it degrades to an indexed array and folds
# every key onto index 0, so associative lookups return each other's values
# without an error. Re-prepending here is Homebrew's own documented setup.
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
