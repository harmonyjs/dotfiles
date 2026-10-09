#!/usr/bin/env bash
# Unit tests for check_stow_dry_run - the real repo as the package, a throwaway dir as the target.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0; fail=0
ok() { if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }

DOTFILES_DIR="$REPO_ROOT"
source "$REPO_ROOT/scripts/lib/common.sh"
source "$REPO_ROOT/scripts/lib/symlinks.sh"
VERBOSE=false

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

ok "empty target: restow would go through" '[[ "$(check_stow_dry_run "$T" 2>/dev/null)" == "1/1" ]]'

printf x > "$T/.zshrc"
ok "plain file where a link goes: red"     '[[ "$(check_stow_dry_run "$T" 2>/dev/null)" == "0/1" ]]'
ok "refusal names the conflicting path"    '[[ "$(check_stow_dry_run "$T" 2>&1 >/dev/null)" == *".zshrc"* ]]'
rm "$T/.zshrc"

mkdir -p "$T/.claude/hooks"
printf x > "$T/.claude/hooks/zsh-colon-modifier-guard.py"
ok "plain file in place of a hook: red"    '[[ "$(check_stow_dry_run "$T" 2>/dev/null)" == "0/1" ]]'

echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
