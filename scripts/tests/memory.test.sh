#!/usr/bin/env bash
# Unit tests for scripts/lib/memory.sh — isolated temp HOME + DOTFILES_DIR fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0; fail=0
ok()   { if eval "$2"; then echo "  ok: $1"; ((pass++)); else echo "  FAIL: $1"; ((fail++)); fi; }

# Source library under a fake environment
source "$REPO_ROOT/scripts/lib/common.sh"
source "$REPO_ROOT/scripts/lib/memory.sh"

setup() {
  T="$(mktemp -d)"
  export HOME="$T/home"
  DOTFILES_DIR="$T/repo"
  VERBOSE=false
  mkdir -p "$HOME/.claude/projects" "$DOTFILES_DIR/.claude/projects"
}
teardown() { rm -rf "$T"; }

# --- id encoding ---
setup
ok "id: slash+dot -> dash" \
  '[[ "$(memory_project_id /Users/a/GitHub/vavilova.dev)" == "-Users-a-GitHub-vavilova-dev" ]]'
ok "id: strips trailing slash" \
  '[[ "$(memory_project_id /Users/a/x/)" == "-Users-a-x" ]]'
teardown

# --- state A: real-only files migrate into repo, dir becomes symlink ---
setup
id="-Users-a-GitHub-proj"
mkdir -p "$HOME/.claude/projects/$id/memory"
printf 'AAA' > "$HOME/.claude/projects/$id/memory/a.md"
printf 'BBB' > "$HOME/.claude/projects/$id/memory/b.md"
link_memory_id "$id"
ok "A: home memory is now a symlink" '[[ -L "$HOME/.claude/projects/$id/memory" ]]'
ok "A: symlink points at repo"       '[[ "$(readlink "$HOME/.claude/projects/$id/memory")" == "$DOTFILES_DIR/.claude/projects/$id/memory" ]]'
ok "A: a.md captured in repo"        '[[ "$(cat "$DOTFILES_DIR/.claude/projects/$id/memory/a.md")" == "AAA" ]]'
ok "A: b.md captured in repo"        '[[ "$(cat "$DOTFILES_DIR/.claude/projects/$id/memory/b.md")" == "BBB" ]]'
teardown

# --- state B: per-file symlinks collapse into one dir symlink, no data loss ---
setup
id="-Users-a-GitHub-projb"
mkdir -p "$DOTFILES_DIR/.claude/projects/$id/memory"
printf 'XXX' > "$DOTFILES_DIR/.claude/projects/$id/memory/x.md"
mkdir -p "$HOME/.claude/projects/$id/memory"
ln -s "$DOTFILES_DIR/.claude/projects/$id/memory/x.md" "$HOME/.claude/projects/$id/memory/x.md"
link_memory_id "$id"
ok "B: home memory is a symlink"  '[[ -L "$HOME/.claude/projects/$id/memory" ]]'
ok "B: x.md still served"         '[[ "$(cat "$HOME/.claude/projects/$id/memory/x.md")" == "XXX" ]]'
teardown

# --- state C: already correct dir symlink is a no-op (idempotent) ---
setup
id="-Users-a-GitHub-projc"
mkdir -p "$DOTFILES_DIR/.claude/projects/$id/memory"
mkdir -p "$HOME/.claude/projects/$id"
ln -s "$DOTFILES_DIR/.claude/projects/$id/memory" "$HOME/.claude/projects/$id/memory"
link_memory_id "$id"; rc=$?
ok "C: returns success" '[[ "$rc" -eq 0 ]]'
ok "C: still a symlink" '[[ -L "$HOME/.claude/projects/$id/memory" ]]'
teardown

# --- conflict: differing same-name file is never overwritten ---
setup
id="-Users-a-GitHub-projx"
mkdir -p "$DOTFILES_DIR/.claude/projects/$id/memory"
printf 'REPO' > "$DOTFILES_DIR/.claude/projects/$id/memory/c.md"
mkdir -p "$HOME/.claude/projects/$id/memory"
printf 'HOME' > "$HOME/.claude/projects/$id/memory/c.md"
link_memory_id "$id"
ok "conflict: repo copy untouched" '[[ "$(cat "$DOTFILES_DIR/.claude/projects/$id/memory/c.md")" == "REPO" ]]'
ok "conflict: home copy stashed"   '[[ -n "$(find "$HOME/.claude/.memory-conflicts/$id" -name "c.md.*" 2>/dev/null)" ]]'
ok "conflict: home memory linked"  '[[ -L "$HOME/.claude/projects/$id/memory" ]]'
teardown

# --- idempotency: second run changes nothing ---
setup
id="-Users-a-GitHub-proji"
mkdir -p "$HOME/.claude/projects/$id/memory"
printf 'ONE' > "$HOME/.claude/projects/$id/memory/a.md"
link_memory_id "$id"; before="$(readlink "$HOME/.claude/projects/$id/memory")"
link_memory_id "$id"; after="$(readlink "$HOME/.claude/projects/$id/memory")"
ok "idempotent: link stable"  '[[ "$before" == "$after" ]]'
ok "idempotent: a.md intact"  '[[ "$(cat "$HOME/.claude/projects/$id/memory/a.md")" == "ONE" ]]'
teardown

echo "---"
echo "passed=$pass failed=$fail"
[[ "$fail" -eq 0 ]]
