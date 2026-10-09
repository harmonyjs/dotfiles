#!/usr/bin/env bash
# Unit tests for check_stow_dry_run and ensure_main_symlinks - the real repo as the package,
# a throwaway HOME as the target.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0; fail=0
ok() { if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }

DOTFILES_DIR="$REPO_ROOT"
source "$REPO_ROOT/scripts/lib/common.sh"
source "$REPO_ROOT/scripts/lib/symlinks.sh"
VERBOSE=false
DRY_RUN=false

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T"
HOOK=.claude/hooks/zsh-colon-modifier-guard.py
verdict() { check_stow_dry_run "$T" 2>/dev/null; }
complaint() { check_stow_dry_run "$T" 2>&1 >/dev/null; }

ok "empty target: every file undelivered"  '[[ "$(verdict)" == "0/1" ]]'

ensure_main_symlinks >/dev/null 2>&1
ok "init stows into an empty home"         '[[ -L "$T/$HOOK" && "$(verdict)" == "1/1" ]]'

rm "$T/$HOOK"
ok "one link missing: red"                 '[[ "$(verdict)" == "0/1" ]]'
ok "names the missing file"                '[[ "$(complaint)" == *"$HOOK"* ]]'

ensure_main_symlinks >/dev/null 2>&1
ok "init restores it while the shell links stand" '[[ -L "$T/$HOOK" && "$(verdict)" == "1/1" ]]'

rm "$T/$HOOK"; printf x > "$T/$HOOK"
ok "plain file in place of a hook: red"    '[[ "$(verdict)" == "0/1" ]]'
ok "conflict names the path"               '[[ "$(complaint)" == *"cannot stow"*"$HOOK"* ]]'

echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
