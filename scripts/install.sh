#!/usr/bin/env bash
set -euo pipefail

echo "🏠 Installing harmonyjs/dotfiles..."
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [[ ! -f ".tmux.conf" ]] || [[ ! -f ".alacritty.toml" ]]; then
    echo -e "${RED}❌ Error: Not in dotfiles directory${NC}"
    echo "Please run this script from the dotfiles directory"
    exit 1
fi

echo "📋 Checking dependencies..."
echo

# Check for required commands
missing_deps=()
for cmd in git tmux stow; do
    if ! command -v $cmd &> /dev/null; then
        missing_deps+=($cmd)
        echo -e "${RED}❌ Missing: $cmd${NC}"
    else
        echo -e "${GREEN}✓ Found: $cmd${NC}"
    fi
done

# If any dependencies are missing, provide installation instructions
if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo
    echo -e "${YELLOW}Please install missing dependencies:${NC}"
    echo "brew install ${missing_deps[*]}"
    exit 1
fi

echo
echo "🔍 Checking tmux version..."

# Check tmux version
if tmux -V | grep -Eq 'tmux 3\.[2-9]|tmux [4-9]'; then
    echo -e "${GREEN}✓ tmux version is 3.2+${NC}"
else
    echo -e "${RED}❌ tmux version is too old (requires 3.2+)${NC}"
    echo "Run: brew upgrade tmux"
    exit 1
fi

echo
echo "📦 Installing TPM (Tmux Plugin Manager)..."

# Install TPM if not already installed
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    echo -e "${GREEN}✓ TPM installed${NC}"
else
    echo -e "${GREEN}✓ TPM already installed${NC}"
fi

echo
echo "🔗 Creating symlinks with GNU Stow..."

# Create symlinks
if stow .; then
    echo -e "${GREEN}✓ Symlinks created${NC}"
else
    echo -e "${RED}❌ Failed to create symlinks${NC}"
    echo "There might be existing files blocking the symlinks"
    echo "Check for conflicts and try again"
    exit 1
fi

echo
echo "🎨 Checking font installation..."

# Check if JetBrainsMono Nerd Font is installed
if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    echo -e "${GREEN}✓ JetBrainsMono Nerd Font is installed${NC}"
else
    echo -e "${YELLOW}⚠️  JetBrainsMono Nerd Font not found${NC}"
    echo "To install the font, run:"
    echo "  brew tap homebrew/cask-fonts"
    echo "  brew install --cask font-jetbrains-mono-nerd-font"
fi

echo
echo "🔌 Installing tmux plugins..."

# Install tmux plugins
if ~/.tmux/plugins/tpm/bin/install_plugins; then
    echo -e "${GREEN}✓ Tmux plugins installed${NC}"
else
    echo -e "${YELLOW}⚠️  Plugin installation may have failed${NC}"
    echo "You can install plugins manually from within tmux with: Prefix + I"
fi

echo
echo "🚀 Loading tmux configuration..."

# Try to load tmux config
if tmux start-server && tmux source-file ~/.tmux.conf 2>/dev/null; then
    echo -e "${GREEN}✓ Tmux configuration loaded${NC}"
else
    echo -e "${YELLOW}⚠️  Could not load tmux config automatically${NC}"
    echo "Config will be loaded when you start tmux"
fi

echo
echo -e "${GREEN}✅ Installation complete!${NC}"
echo
echo "Next steps:"
echo "1. Restart your terminal or run: tmux source ~/.tmux.conf"
echo "2. Open Alacritty to start using your new setup"
echo
echo "For detailed documentation, see:"
echo "  • docs/TMUX.md"
echo "  • docs/ALACRITTY.md"
echo
echo "To verify installation, run: ./scripts/verify-setup.sh"
