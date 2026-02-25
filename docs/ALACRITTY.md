# Alacritty Configuration

## Tmux Integration

This setup auto-starts tmux session "main" when Alacritty opens:

```toml
[terminal.shell]
program = "/bin/zsh"
args = ["-lc", "exec tmux new-session -A -s main"]
```

How it works:
- Alacritty launches a **login shell** (`zsh -l`), which sources `.zshenv` to set up Homebrew PATH
- `exec tmux` replaces the shell process with tmux (no orphan shell left behind)
- Creates or attaches to session named "main" (`-A` flag)
- Session persists when Alacritty closes
- Works on both Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`) Macs

## Multiple Windows

To work with multiple Alacritty instances:

```bash
# New window with same session
Prefix + c  # Create new tmux window

# New Alacritty window
cmd + n     # macOS shortcut
```

All windows share the same tmux session "main".

## Troubleshooting

### Tmux Not Found

Alacritty relies on the login shell's PATH to find tmux. If tmux isn't launching:

```bash
# Verify tmux is discoverable via login shell
zsh -lc "which tmux"

# Should output one of:
#   /opt/homebrew/bin/tmux  (Apple Silicon)
#   /usr/local/bin/tmux     (Intel)
```

If this fails, check that `.zshenv` has the Homebrew `eval` block and that tmux is installed (`brew install tmux`).

### Font Problems

Requires JetBrainsMono Nerd Font:

```bash
# Install if missing
brew install --cask font-jetbrains-mono-nerd-font

# Verify installation
fc-list | grep -i jetbrains
```

### Debug Tmux Startup

Run the same command Alacritty uses, manually:

```bash
zsh -lc "exec tmux new-session -A -s main"
```

## Project-Specific Sessions

For different projects, modify the session name in `alacritty.toml`:

```toml
[terminal.shell]
args = ["-lc", "exec tmux new-session -A -s project-name"]
```

Or create aliases in `.zsh_aliases`:

```bash
alias work='alacritty -e zsh -lc "exec tmux new-session -A -s work"'
alias personal='alacritty -e zsh -lc "exec tmux new-session -A -s personal"'
```
