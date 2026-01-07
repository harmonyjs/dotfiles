# Alacritty Configuration

## Tmux Integration

This setup auto-starts tmux session "main" when Alacritty opens:

```toml
[terminal.shell]
program = "/opt/homebrew/bin/tmux"                
args = ["-v", "new-session", "-A", "-s", "main"] 
```

- Creates or attaches to session named "main"
- Enables verbose logging (`-v`) for debugging
- Session persists when Alacritty closes

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

### Tmux Path Issues
Configuration expects tmux at `/opt/homebrew/bin/tmux`:

```bash
# Check tmux location
which tmux
# Should output: /opt/homebrew/bin/tmux

# If different path, update .config/alacritty/alacritty.toml:
program = "/path/to/your/tmux"
```

### Font Problems
Requires JetBrainsMono Nerd Font:

```bash
# Install if missing
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# Verify installation
fc-list | grep -i jetbrains
```

### Debug Tmux Startup
Enable verbose logging (already configured):

```bash
# Check tmux logs or run directly
/opt/homebrew/bin/tmux -v new-session -A -s main
```

## Project-Specific Sessions

For different projects, modify the session name:

```toml
[terminal.shell]
args = ["-v", "new-session", "-A", "-s", "project-name"]
```

Or create aliases in `.zshrc`:

```bash
alias work='alacritty -e tmux new-session -A -s work'
alias personal='alacritty -e tmux new-session -A -s personal'
