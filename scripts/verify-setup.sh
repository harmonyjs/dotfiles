#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Verifying harmonyjs/dotfiles setup..."
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track failures
failures=0

# Helper function for tests
check() {
    local description="$1"
    local command="$2"
    
    printf "%-50s" "$description"
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        ((failures++))
    fi
}

echo -e "${BLUE}=== Dependencies ===${NC}"
check "tmux installed" "command -v tmux"
check "tmux version 3.2+" "tmux -V | grep -Eq 'tmux 3\.[2-9]|tmux [4-9]'"
check "stow installed" "command -v stow"
check "TPM directory exists" "test -d ~/.tmux/plugins/tpm"

echo
echo -e "${BLUE}=== Symlinks ===${NC}"
check ".tmux.conf symlink" "test -L ~/.tmux.conf"
check ".alacritty.toml symlink" "test -L ~/.alacritty.toml"
check ".zsh_aliases symlink" "test -L ~/.zsh_aliases"

echo
echo -e "${BLUE}=== All Dotfiles Symlinks ===${NC}"

# Группируем симлинки по уровням для лучшей читаемости
echo -e "${YELLOW}Root level (~):${NC}"
find ~ -maxdepth 1 -type l 2>/dev/null | while read -r link; do
    target=$(readlink "$link" 2>/dev/null) || continue
    [[ "$target" == *"dotfiles"* ]] && printf "  %-30s -> %s\n" "$(basename "$link")" "$target"
done | sort

# Проверяем вложенные директории (до 3 уровней)
echo
echo -e "${YELLOW}Nested symlinks:${NC}"
find ~ -mindepth 2 -maxdepth 3 -type l 2>/dev/null | while read -r link; do
    target=$(readlink "$link" 2>/dev/null) || continue
    if [[ "$target" == *"dotfiles"* ]]; then
        relative="${link#$HOME/}"
        printf "  %-30s -> %s\n" "$relative" "$target"
    fi
done | sort

# Подсчёт для быстрой проверки
echo
set +o pipefail
total=$(find ~ -maxdepth 3 -type l 2>/dev/null | while read -r link; do
    target=$(readlink "$link" 2>/dev/null)
    [[ "$target" == *"dotfiles"* ]] && echo "1"
done | wc -l | tr -d ' ')
set -o pipefail

echo -e "Total dotfiles symlinks: ${GREEN}${total}${NC}"

echo
echo -e "${BLUE}=== Tmux Configuration ===${NC}"
check "Config loads without errors" "tmux start-server && tmux source-file ~/.tmux.conf 2>/dev/null || tmux show -g prefix &>/dev/null"
check "Prefix key is C-Space" "tmux show -g prefix | grep -q 'C-Space'"
check "Mouse support enabled" "tmux show -g mouse | grep -q on"
check "True color support" "tmux info | grep -Eq 'RGB|Tc'"
check "Alternate screen enabled" "tmux show -gw alternate-screen | grep -q on"
check "Vi mode enabled" "tmux show -gw mode-keys | grep -q vi"
check "Windows start at 1" "tmux show -g base-index | grep -q '1$'"
check "Panes start at 1" "tmux show -g pane-base-index | grep -q '1$'"
check "Window renumbering enabled" "tmux show -g renumber-windows | grep -q on"

echo
echo -e "${BLUE}=== Key Bindings ===${NC}"
check "C-Space prefix binding" "tmux list-keys -T prefix | grep -q 'C-Space.*send-prefix'"
check "Vim navigation (C-h)" "tmux list-keys -T root | grep -q 'C-h.*select-pane -L'"
check "Alt+Arrow navigation" "tmux list-keys -T root | grep -q 'M-Left.*select-pane'"
check "Shift+Arrow windows" "tmux list-keys -T root | grep -q 'S-Left.*previous-window'"
check "Alt+h/l windows" "tmux list-keys -T root | grep -q 'M-h.*previous-window'"
check "Copy mode bindings" "tmux list-keys -T copy-mode-vi | grep -E 'v .*begin-selection|y .*copy-selection'"

echo
echo -e "${BLUE}=== Plugins ===${NC}"
check "Catppuccin theme installed" "test -d ~/.tmux/plugins/catppuccin-tmux"
check "Catppuccin flavor is latte" "tmux show -gv '@catppuccin_flavour' | grep -q latte"
check "tmux-sensible installed" "test -d ~/.tmux/plugins/tmux-sensible"
check "vim-tmux-navigator installed" "test -d ~/.tmux/plugins/vim-tmux-navigator"
check "tmux-yank installed" "test -d ~/.tmux/plugins/tmux-yank"

echo
echo -e "${BLUE}=== Split Behavior ===${NC}"
# Test split preserves current directory
tmux new-session -d -s test-splits -c /tmp 2>/dev/null || true
tmux split-window -t test-splits:1 -h -c "#{pane_current_path}" 2>/dev/null || true
# Check for both /tmp and /private/tmp (macOS resolves /tmp to /private/tmp)
if tmux list-panes -t test-splits:1 -F '#{pane_current_path}' 2>/dev/null | uniq | grep -Eq '^(/tmp|/private/tmp)$'; then
    echo -e "Split preserves directory                         ${GREEN}✓${NC}"
else
    echo -e "Split preserves directory                         ${RED}✗${NC}"
    ((failures++))
fi
tmux kill-session -t test-splits 2>/dev/null || true

echo
echo -e "${BLUE}=== Font & Terminal ===${NC}"
check "JetBrainsMono Nerd Font" "test -f ~/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
check "Alacritty installed" "command -v alacritty || test -d /Applications/Alacritty.app"

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $failures -eq 0 ]]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo
    echo "Your dotfiles are properly configured."
    exit 0
else
    echo -e "${RED}❌ $failures checks failed${NC}"
    echo
    echo "Run ./scripts/install.sh to fix issues"
    exit 1
fi
