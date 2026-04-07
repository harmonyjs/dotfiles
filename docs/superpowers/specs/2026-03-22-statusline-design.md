> **Superseded** by [statusline-v2](2026-04-07-statusline-v2-design.md).

# Claude Code Statusline Script

## Summary

Extract the inline statusline command from `.claude/settings.json` into a standalone
ZSH script (`.claude/statusline.zsh`) that displays the model name and a 10-character
context window progress bar with color-coded fill level.

## Output Format

Single line:

```
Opus 4.6  ▰▰▰▰▰▱▱▱▱▱
```

- Model name in dim gray (`\033[38;5;8m`)
- Two-space separator
- 10-character bar: `▰` (filled) / `▱` (empty)
- Bar color by threshold:
  - Green (`\033[32m`) — below 50%
  - Yellow (`\033[33m`) — 50% to 79%
  - Red (`\033[31m`) — 80% and above
- No numeric percentage displayed

## Architecture

**File:** `.claude/statusline.zsh` (inside the `.claude` git submodule, symlinked to `~/.claude/`)

**Prerequisites:**
- Shebang: `#!/usr/bin/env zsh`
- File must be executable (`chmod +x`)
- Committed to the `.claude` submodule repo, not the parent dotfiles repo

**Data flow:**

1. Claude Code pipes session JSON to script's stdin
2. Single `jq` call extracts `model.display_name` and `context_window.used_percentage`
3. ZSH computes filled block count via integer division
4. ZSH selects ANSI color based on thresholds
5. ZSH builds bar string from pre-allocated character arrays and prints result

**settings.json change:** Replace inline `command` value with `~/.claude/statusline.zsh`.

## Implementation Details

### JSON Parsing (one jq invocation)

```zsh
IFS=$'\t' read -r model pct <<< "$(jq -r '[.model.display_name, (.context_window.used_percentage // 0 | floor)] | @tsv' 2>/dev/null)"
```

- `IFS=$'\t'` — split on tab only (model names contain spaces, e.g. "Opus 4.6")
- `@tsv` produces tab-separated output for `read` to split
- `// 0` handles null (before first API call)
- `floor` ensures integer
- `2>/dev/null` suppresses errors if `jq` is missing or input is malformed

If `model` is empty after parsing, exit silently (no output).

### Bar Calculation

```zsh
(( filled = pct / 10 ))
(( filled > 10 )) && filled=10
```

ZSH integer arithmetic: 52% → 5 filled blocks. Clamped to 10 max
in case the API ever reports > 100%.

### Color Selection

```zsh
if (( pct >= 80 )); then   color='\033[31m'   # red
elif (( pct >= 50 )); then  color='\033[33m'   # yellow
else                         color='\033[32m'   # green
fi
```

### Bar Assembly (no loops, no forks)

```zsh
local full='▰▰▰▰▰▰▰▰▰▰'
local empty='▱▱▱▱▱▱▱▱▱▱'
local bar="${full:0:$filled}${empty:0:$((10 - filled))}"
```

Substring slicing from pre-built strings — faster than loops.

### Output

```zsh
printf '\033[38;5;8m%s\033[0m  %b%s\033[0m' "$model" "$color" "$bar"
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `used_percentage` is null (pre-first API call) | `pct` = 0, bar is 10 × `▱`, green |
| `used_percentage` = 0 | 10 × `▱`, green |
| `used_percentage` = 100 | 10 × `▰`, red |
| `used_percentage` > 100 | Clamped to 10 filled blocks, red |
| `jq` missing or stdin malformed | jq stderr suppressed via `2>/dev/null`; `read` gets empty strings; script exits early with no output |

## Files Changed

| File | Change |
|------|--------|
| `.claude/statusline.zsh` | New file — the statusline script |
| `.claude/settings.json` | Update `statusLine.command` to `~/.claude/statusline.zsh` |

## Documentation

The script itself contains section comments explaining each step.
No separate documentation file needed — the script is the documentation.
