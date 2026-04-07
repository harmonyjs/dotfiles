# Statusline v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `.claude/statusline.zsh` — replace progress bar with conditional context labels, add mytonwallet-org branch display, hide default model.

**Architecture:** Single zsh script, stdin JSON → conditional element array → joined output. No external deps beyond `jq` and `git`.

**Tech Stack:** ZSH, jq, git, ANSI escape codes

**Spec:** `docs/superpowers/specs/2026-04-07-statusline-v2-design.md`

---

### Task 1: Rewrite JSON parsing to extract all needed fields

**Files:**
- Modify: `.claude/statusline.zsh`

- [ ] **Step 1: Replace the jq call to extract 5 fields**

Replace the entire content of `.claude/statusline.zsh` with the new parsing header:

```zsh
#!/usr/bin/env zsh
#
# Claude Code statusline v2 — conditional model name, context labels, project branches.
#
# Input:  session JSON on stdin (piped by Claude Code after each assistant message)
# Output: single ANSI-colored line to stdout, or nothing
#
# Elements (joined by " · "):
#   - Model name (hidden for Opus 1M)
#   - Context label: "100k" (bold orange) or "200k" (red bg, white bold)
#   - Repository branches for mytonwallet-org

# --- Parse JSON (single jq call) ---
IFS=$'\t' read -r model model_id ctx_size pct cwd <<< "$(jq -r '
  [
    .model.display_name,
    .model.id,
    (.context_window.context_window_size // 0),
    (.context_window.used_percentage // 0 | floor),
    (.cwd // "")
  ] | @tsv' 2>/dev/null)"

# If parsing failed, produce no output.
[[ -z "$model" || "$pct" != <-> ]] && exit 0
```

- [ ] **Step 2: Verify parsing works**

Run:
```bash
echo '{"model":{"display_name":"Sonnet","id":"claude-sonnet-4-6"},"context_window":{"context_window_size":200000,"used_percentage":52},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: no output yet (script has no printf), but no errors either. Exit code 0.

- [ ] **Step 3: Commit**

```bash
cd /Users/andreyvavilov/GitHub/dotfiles/.claude
git add statusline.zsh
git commit -m "refactor(statusline): rewrite JSON parsing for v2 fields"
```

---

### Task 2: Build conditional element array

**Files:**
- Modify: `.claude/statusline.zsh`

- [ ] **Step 1: Add element assembly logic after the parsing block**

Append after the `exit 0` guard:

```zsh
# --- Compute derived values ---
(( used_tokens = pct * ctx_size / 100 ))

# --- ANSI codes ---
local -r DIM='\033[38;5;8m'
local -r BOLD_ORANGE='\033[1;38;5;208m'
local -r RED_BG_WHITE='\033[41;1;37m'
local -r RST='\033[0m'

# --- Assemble elements ---
local -a parts=()

# 1. Model name (hidden for Opus with 1M context)
if [[ "$model_id" != *opus* || "$ctx_size" -ne 1000000 ]]; then
  parts+=("${DIM}${model}${RST}")
fi

# 2. Context usage label
if (( used_tokens >= 200000 )); then
  parts+=("${RED_BG_WHITE} 200k ${RST}")
elif (( used_tokens >= 100000 )); then
  parts+=("${BOLD_ORANGE}100k${RST}")
fi

# 3. Repository branches (mytonwallet-org only)
if [[ "$cwd" == "/Users/andreyvavilov/GitHub/mytonwallet-org" ]]; then
  local -A repos=(dev mytonwallet-dev backend mytonwallet-backend deploy mytonwallet-deploy)
  local short branch
  for short in dev backend deploy; do
    branch=$(git -C "${cwd}/${repos[$short]}" branch --show-current 2>/dev/null)
    if [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]]; then
      parts+=("${DIM}${short}::${branch}${RST}")
    fi
  done
fi
```

- [ ] **Step 2: Verify model hiding works**

Opus 1M — should produce no model element:
```bash
echo '{"model":{"display_name":"Opus 4.6","id":"claude-opus-4-6"},"context_window":{"context_window_size":1000000,"used_percentage":5},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: no output (no elements, no printf yet).

Sonnet — should produce model element:
```bash
echo '{"model":{"display_name":"Sonnet","id":"claude-sonnet-4-6"},"context_window":{"context_window_size":200000,"used_percentage":5},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: no visible output yet (no printf), but no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/andreyvavilov/GitHub/dotfiles/.claude
git add statusline.zsh
git commit -m "feat(statusline): add conditional element assembly"
```

---

### Task 3: Add output with middle dot separator

**Files:**
- Modify: `.claude/statusline.zsh`

- [ ] **Step 1: Add the output block at the end of the script**

Append:

```zsh
# --- Output ---
# Nothing to show → empty statusline
(( ${#parts} == 0 )) && exit 0

# Join elements with " · " (middle dot U+00B7)
local sep=" ${DIM}·${RST} "
local output="${parts[1]}"
for p in "${parts[@]:1}"; do
  output+="${sep}${p}"
done

printf '%b' "$output"
```

- [ ] **Step 2: Verify — Opus 1M, low context, not mytonwallet**

```bash
echo '{"model":{"display_name":"Opus 4.6","id":"claude-opus-4-6"},"context_window":{"context_window_size":1000000,"used_percentage":5},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: empty output (all elements hidden).

- [ ] **Step 3: Verify — Sonnet, low context**

```bash
echo '{"model":{"display_name":"Sonnet","id":"claude-sonnet-4-6"},"context_window":{"context_window_size":200000,"used_percentage":5},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: `Sonnet` in dim gray.

- [ ] **Step 4: Verify — Opus 1M, 150k tokens**

```bash
echo '{"model":{"display_name":"Opus 4.6","id":"claude-opus-4-6"},"context_window":{"context_window_size":1000000,"used_percentage":15},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: `100k` in bold orange (15% of 1M = 150k).

- [ ] **Step 5: Verify — Sonnet, 250k tokens**

```bash
echo '{"model":{"display_name":"Sonnet","id":"claude-sonnet-4-6"},"context_window":{"context_window_size":1000000,"used_percentage":25},"cwd":"/tmp"}' | ~/.claude/statusline.zsh
```
Expected: `Sonnet · 200k` (Sonnet dim gray, 200k red bg white bold).

- [ ] **Step 6: Verify — Opus 1M, mytonwallet-org cwd**

```bash
echo '{"model":{"display_name":"Opus 4.6","id":"claude-opus-4-6"},"context_window":{"context_window_size":1000000,"used_percentage":5},"cwd":"/Users/andreyvavilov/GitHub/mytonwallet-org"}' | ~/.claude/statusline.zsh
```
Expected: branches of non-main/master repos shown (depends on current branch state), or empty if all on master.

- [ ] **Step 7: Commit**

```bash
cd /Users/andreyvavilov/GitHub/dotfiles/.claude
git add statusline.zsh
git commit -m "feat(statusline): output with middle dot separator"
```

---

### Task 4: Update spec and clean up

**Files:**
- Modify: `docs/superpowers/specs/2026-03-22-statusline-design.md` (add note about v2 superseding)

- [ ] **Step 1: Add superseded note to old spec**

Add to the top of `docs/superpowers/specs/2026-03-22-statusline-design.md`:

```markdown
> **Superseded** by [statusline-v2](2026-04-07-statusline-v2-design.md).
```

- [ ] **Step 2: Final end-to-end verification**

Run `just check` from dotfiles root to make sure nothing is broken.

- [ ] **Step 3: Commit**

```bash
cd /Users/andreyvavilov/GitHub/dotfiles
git add docs/superpowers/specs/2026-03-22-statusline-design.md
git commit -m "docs: mark statusline v1 spec as superseded"
```
