# Claude Code Statusline v2

Rework of `.claude/statusline.zsh` — replaces progress bar with contextual labels,
adds project-aware branch display, and conditionally hides default model.

## Input

Session JSON on stdin from Claude Code. Fields used:

| Field | Type | Purpose |
|-------|------|---------|
| `model.display_name` | string | Model label for display |
| `model.id` | string | Model identification (e.g. `claude-opus-4-6`) |
| `context_window.context_window_size` | int | Total context window in tokens |
| `context_window.used_percentage` | float | Percent of context used |
| `cwd` | string | Current working directory |

Derived value: `used_tokens = used_percentage * context_window_size / 100` (zsh integer arithmetic).

## Output Format

Conditional elements joined by ` · ` (space, middle dot U+00B7, space).
Empty statusline (exit 0) when no elements qualify.

### Elements (in order)

#### 1. Model name

- **Hidden** when `model.id` contains `opus` AND `context_window_size` == 1000000
- **Shown** otherwise, dim gray

#### 2. Context usage label

- `used_tokens >= 200000` → **"200k"** — red background, white bold
- `used_tokens >= 100000` → **"100k"** — bold orange
- `used_tokens < 100000` → nothing

#### 3. Repository branches (project-specific)

Only when `cwd` == `/Users/andreyvavilov/GitHub/mytonwallet-org`.

Three repositories checked:

| Directory | Short name |
|-----------|-----------|
| `mytonwallet-dev` | `dev` |
| `mytonwallet-backend` | `backend` |
| `mytonwallet-deploy` | `deploy` |

For each: `git -C <path> branch --show-current 2>/dev/null`.
Branch `main` or `master` → skip. Otherwise → `<short>::<branch>` in dim gray.

## ANSI Styling

| Element | Style | ANSI code |
|---------|-------|-----------|
| Model name | dim gray | `\033[38;5;8m` |
| "100k" label | bold orange | `\033[1;38;5;208m` |
| "200k" label | red bg, white bold | `\033[41;1;37m` |
| Branch info | dim gray | `\033[38;5;8m` |
| Middle dot | dim gray | `\033[38;5;8m` |
| Reset | — | `\033[0m` |

Each element formatted individually with its own escape sequence.
Middle dot separator always dim gray.

## Output Examples

| Scenario | Output |
|----------|--------|
| Opus 1M, 50k tokens, not mytonwallet | *(empty)* |
| Opus 1M, 150k tokens, not mytonwallet | `100k` |
| Opus 1M, 250k tokens, not mytonwallet | `200k` |
| Sonnet, 30k tokens, not mytonwallet | `Sonnet` |
| Sonnet, 250k tokens, not mytonwallet | `Sonnet · 200k` |
| Opus 1M, 50k, mytonwallet, backend on feature | `backend::feat/campaign` |
| Opus 1M, 150k, mytonwallet, all on master | `100k` |
| Sonnet, 150k, mytonwallet, dev on feature | `Sonnet · 100k · dev::feat/new-ui` |

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `used_percentage` is null | Defaults to 0, no context label |
| `context_window_size` is null | Defaults to 0, no context label |
| `cwd` is null | No branch display |
| Git repo dir missing | `git` fails silently (2>/dev/null), branch skipped |
| All branches on main/master | No branch elements added |
| All elements empty | exit 0, empty statusline |
| jq missing or malformed input | Silent exit 0 |

## Architecture

Single file: `.claude/statusline.zsh` (in `.claude` git submodule).
No external dependencies beyond `jq` and `git`.
No loops for element assembly — conditional appends to zsh array, single printf at the end.

## Files Changed

| File | Change |
|------|--------|
| `.claude/statusline.zsh` | Rewrite — remove bar, add conditional elements |
