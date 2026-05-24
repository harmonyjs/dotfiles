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

One gate per 100k tokens: `gate = floor(used_tokens / 100000) * 100`.
Label text is `<gate>k`; style escalates with fill.

| Gate | Style |
|------|-------|
| 100k | yellow, bold |
| 200k | red, bold |
| 300k | yellow background, white bold |
| 400k | red background, white bold |
| 500k…1000k | black background, white bold |

`used_tokens < 100000` → nothing.

#### 3. Repository branches (project-specific)

Shown only when `cwd` starts with `/Users/andreyvavilov/GitHub/mytonwallet-org` (prefix match — works from any subdirectory).

**Discovery.** Every git repository directly under `mytonwallet-org/` is scanned via
`git -C <dir> branch --show-current`. A repo on `main` or `master` is skipped; the rest
are displayed. The label is the directory name with a leading `mytonwallet-` stripped
(`mytonwallet-dev` → `dev`).

**Width-budgeted compaction.** The repo segment must fit within `MTW_REPO_BUDGET` visible
characters (default 100). An escalation ladder applies progressively lossier transforms
and stops at the lowest stage whose rendered segment fits the budget:

| Stage | Transform |
|-------|-----------|
| 0 | `<label>::<branch>` in full |
| 1 | strip the branch's `type/` prefix (everything up to the last `/`) |
| 2 | truncate the branch at a word boundary (`-._/`) to an adaptive target |
| 3 | truncate the branch with an ellipsis to the adaptive target |
| 4 | replace the label with a minimal unique code |
| 5 | drop trailing repos, collapsing the remainder into a `+M` counter |

The adaptive branch target is `budget/N − labelWidth − 2`, floored at `MTW_BRANCH_MIN`
(default 6): few repos keep long branch names, many repos shrink them.

**Minimal unique label code (stage 4).** Each label starts as its first letter. Codes
that collide are escalated — a name containing `-` or `.` switches to its token initials
(`dev-fix-snapshot` → `dfs`), a name without separators extends one character at a time
(`deploy` → `dep`). Uniqueness is resolved against *every* git repo under
`mytonwallet-org`, not just the displayed ones, so a repo's code is stable across
renders. Computed lazily — only when stage 4 is reached.

Each rendered entry (and the `+M` counter) is dim gray.

## ANSI Styling

| Element | Style | ANSI code |
|---------|-------|-----------|
| Model name | dim gray | `\033[38;5;8m` |
| 100k gate | yellow, bold | `\033[1;33m` |
| 200k gate | red, bold | `\033[1;31m` |
| 300k gate | yellow bg, white bold | `\033[43;1;37m` |
| 400k gate | red bg, white bold | `\033[41;1;37m` |
| 500k+ gate | black bg, white bold | `\033[40;1;37m` |
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
| Opus 1M, 550k tokens, not mytonwallet | `500k` |
| Opus 1M, 1000k tokens, not mytonwallet | `1000k` |
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

Model, context, and overtime elements are conditional appends to a zsh array. The repo
segment is assembled by a compaction ladder built from helper functions: `_render`
(build entries for a stage), `_seg_width` (visible width), `_word_trunc` / `_ell_trunc`
(branch truncation), `_candidate` / `_compute_aliases` (minimal unique label codes).
Helpers communicate via globals to keep the hot path free of subshell forks. Single
printf at the end.

## Files Changed

| File | Change |
|------|--------|
| `.claude/statusline.zsh` | Rewrite — remove bar, add conditional elements |
