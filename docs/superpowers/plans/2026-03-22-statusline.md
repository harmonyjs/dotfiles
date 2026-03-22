# Claude Code Statusline Script — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inline statusline command with a standalone ZSH script that shows model name + color-coded context window progress bar.

**Architecture:** Single ZSH script reads JSON from stdin via one `jq` call, computes a 10-char progress bar with green/yellow/red thresholds, and prints ANSI-formatted output. `settings.json` points to the script path.

**Tech Stack:** ZSH, jq

**Spec:** `docs/superpowers/specs/2026-03-22-statusline-design.md`

---

### Task 1: Create the statusline script

**Files:**
- Create: `.claude/statusline.zsh`

- [ ] **Step 1: Write the script**

Create `.claude/statusline.zsh` with the full implementation:

```zsh
#!/usr/bin/env zsh
#
# Claude Code statusline — displays model name and context window usage bar.
#
# Input:  session JSON on stdin (piped by Claude Code after each assistant message)
# Output: single ANSI-colored line to stdout
#
# Format:  Opus 4.6  ▰▰▰▰▰▱▱▱▱▱
#          ~~~~~~~~  ~~~~~~~~~~
#          dim gray  color-coded bar (green < 50%, yellow 50-79%, red >= 80%)
#
# Bar uses 10 blocks: ▰ (filled) and ▱ (empty).
# No numeric percentage is shown.

# --- Parse JSON (single jq call) ---
# IFS=$'\t' ensures model names with spaces (e.g. "Opus 4.6") are not split.
# jq outputs two tab-separated values: display_name and used_percentage (floored integer).
# 2>/dev/null suppresses errors if jq is missing or input is malformed.
IFS=$'\t' read -r model pct <<< "$(jq -r '[.model.display_name, (.context_window.used_percentage // 0 | floor)] | @tsv' 2>/dev/null)"

# If parsing failed, produce no output
[[ -z "$model" ]] && exit 0

# --- Compute bar fill (0–10 blocks) ---
(( filled = pct / 10 ))
(( filled > 10 )) && filled=10

# --- Select bar color by context usage threshold ---
if (( pct >= 80 )); then   color='\033[31m'   # red: context is running low
elif (( pct >= 50 )); then  color='\033[33m'   # yellow: past halfway
else                         color='\033[32m'   # green: plenty of room
fi

# --- Assemble bar from pre-built strings (no loops, no forks) ---
local full='▰▰▰▰▰▰▰▰▰▰'
local empty='▱▱▱▱▱▱▱▱▱▱'
local bar="${full:0:$filled}${empty:0:$((10 - filled))}"

# --- Output ---
printf '\033[38;5;8m%s\033[0m  %b%s\033[0m' "$model" "$color" "$bar"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x .claude/statusline.zsh`

- [ ] **Step 3: Create symlink via stow**

Run: `just stow`
Verify: `ls -la ~/.claude/statusline.zsh` — should be a symlink to `../GitHub/dotfiles/.claude/statusline.zsh`

- [ ] **Step 4: Verify — green bar (25%)**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":25}}' | ~/.claude/statusline.zsh
```
Expected: `Opus 4.6` in gray, 2 filled + 8 empty blocks in green.

- [ ] **Step 5: Verify — yellow bar (65%)**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":65}}' | ~/.claude/statusline.zsh
```
Expected: 6 filled + 4 empty blocks in yellow.

- [ ] **Step 6: Verify — red bar (92%)**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":92}}' | ~/.claude/statusline.zsh
```
Expected: 9 filled + 1 empty block in red.

- [ ] **Step 7: Verify edge case — 0%**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":0}}' | ~/.claude/statusline.zsh
```
Expected: `Opus 4.6` in gray, 10 empty blocks in green.

- [ ] **Step 8: Verify edge case — 100%**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":100}}' | ~/.claude/statusline.zsh
```
Expected: 10 filled blocks in red.

- [ ] **Step 9: Verify edge case — over 100% (clamping)**

Run:
```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":115}}' | ~/.claude/statusline.zsh
```
Expected: 10 filled blocks in red (clamped, no extra characters).

- [ ] **Step 10: Verify edge case — null percentage**

Run:
```bash
echo '{"model":{"display_name":"Sonnet 4.6"},"context_window":{}}' | ~/.claude/statusline.zsh
```
Expected: `Sonnet 4.6` in gray, 10 empty blocks in green.

- [ ] **Step 11: Verify edge case — malformed input**

Run:
```bash
echo 'not json' | ~/.claude/statusline.zsh; echo "exit: $?"
```
Expected: no output, exit code 0.

- [ ] **Step 12: Commit the script in the .claude submodule**

```bash
git -C .claude add statusline.zsh
git -C .claude commit -m "feat: add statusline script with context window progress bar"
```

---

### Task 2: Update settings.json to use the script

**Files:**
- Modify: `.claude/settings.json:2-4` (the `statusLine` block)

- [ ] **Step 1: Replace inline command with script path**

Change the `statusLine` block in `.claude/settings.json` from:
```json
"statusLine": {
  "type": "command",
  "command": "printf '\\033[38;5;8m%s\\033[0m' \"$(cat | jq -r '.model.display_name')\""
}
```
to:
```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.zsh"
}
```

- [ ] **Step 2: Commit the settings change in the .claude submodule**

```bash
git -C .claude add settings.json
git -C .claude commit -m "refactor: point statusline to external script"
```

---

### Task 3: Update parent repo submodule ref

**Files:**
- Modify: `.claude` (submodule ref in parent repo)

- [ ] **Step 1: Push .claude submodule changes**

```bash
git -C .claude push origin main
```

- [ ] **Step 2: Stage and commit updated submodule ref in parent**

```bash
git add .claude
git commit -m "chore: update .claude submodule"
```

- [ ] **Step 3: Run `just check` to verify nothing is broken**

Run: `just check`
Expected: all checks pass.

- [ ] **Step 4: Verify statusline works in a live Claude Code session**

Restart Claude Code (or start a new session) and confirm the statusline shows the model name and a colored progress bar at the bottom of the terminal.
