# Tmux Configuration

## Key Bindings

### Prefix
- `Ctrl+Space` - Main prefix (instead of default `Ctrl+b`)
- `Ctrl+Space Ctrl+Space` - Send prefix to nested session

### Navigation (No Prefix)
| Key | Action |
|-----|--------|
| `Ctrl+h/j/k/l` | Navigate panes (vim-style) |
| `Alt+Arrow Keys` | Navigate panes |
| `Shift+Left/Right` | Switch windows |
| `Alt+h/l` | Switch windows (vim-style) |

### Window & Pane Management (With Prefix)
| Key | Action |
|-----|--------|
| `Prefix + "` | Split horizontally |
| `Prefix + %` | Split vertically |
| `Prefix + c` | Create new window |
| `Prefix + ,` | Rename window |

### Copy Mode (With Prefix)
| Key | Action |
|-----|--------|
| `Prefix + [` | Enter copy mode |
| `v` | Begin selection (in copy mode) |
| `Ctrl+v` | Rectangle selection |
| `y` | Copy and exit |

## Vim-Tmux Navigator Integration

This config uses `vim-tmux-navigator` plugin for seamless navigation:

- `Ctrl+h/j/k/l` works across vim splits and tmux panes
- No prefix needed for navigation
- Automatically detects vim instances

If navigation breaks between vim and tmux:
```bash
# Ensure plugin is installed in both vim and tmux
# Check tmux plugin: ~/.tmux/plugins/vim-tmux-navigator
# Check vim plugin in your vim config
```

## Session Management

### Common Commands
```bash
# List sessions
tmux list-sessions

# Create named session
tmux new-session -s project-name

# Attach to session
tmux attach-session -t session-name

# Kill session
tmux kill-session -t session-name
```

### In-Session Commands
| Key | Action |
|-----|--------|
| `Prefix + d` | Detach session |
| `Prefix + s` | List/switch sessions |
| `Prefix + $` | Rename session |

## Quick Troubleshooting

### Health Check
```bash
# Check prefix key
tmux show -g prefix | grep -q 'C-Space' && echo "✓ Prefix OK"

# Check mouse support
tmux show -g mouse | grep -q on && echo "✓ Mouse OK"

# Check plugins
test -d ~/.tmux/plugins/catppuccin-tmux && echo "✓ Plugins OK"
```

### Common Issues

**Config not loading:**
```bash
tmux source-file ~/.config/tmux/tmux.conf
```

**Plugins not working:**
```bash
# Reinstall TPM
rm -rf ~/.tmux/plugins/
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/bin/install_plugins
```

**Colors wrong:**
```bash
# Check terminal support
echo $TERM
# Should be: tmux-256color or xterm-256color
```

**Navigation not working:**
- Ensure vim-tmux-navigator is installed in both vim and tmux
- Check that key bindings match in both configs

## Catppuccin Theme

Current flavor: `latte` (light theme)

To change theme:
```bash
# In .config/tmux/tmux.conf, modify:
set -g @catppuccin_flavour 'latte'    # Light
# set -g @catppuccin_flavour 'mocha'  # Dark
```

After changing, reload config and reinstall plugins:
```bash
tmux source-file ~/.config/tmux/tmux.conf
~/.tmux/plugins/tpm/bin/update_plugins
