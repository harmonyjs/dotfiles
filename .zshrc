# ZSH Configuration
# Author: harmonyjs
# Repository: https://github.com/harmonyjs/dotfiles
#
# This file contains shared ZSH configurations that are version controlled.
# Machine-specific settings should go in ~/.zshrc.local

#
# History
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.

#
# Starship Prompt
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

eval "$(starship init zsh)"

#
# Completion
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

autoload -Uz compinit && compinit

#
# Utilities
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide
eval "$(zoxide init zsh)"

# fnm (Fast Node Manager)
eval "$(fnm env --version-file-strategy=recursive)"
autoload -U add-zsh-hook
_fnm_autoload() { fnm use --install-if-missing --silent-if-unchanged 2>/dev/null }
add-zsh-hook chpwd _fnm_autoload
_fnm_autoload

# Doppler
eval "$(doppler completion zsh)"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

#
# Tmux window title
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

# Automatically set tmux window title: show full path for shells, command with args for apps
if [[ -n "$TMUX" ]]; then
  precmd() {
    # For shell prompt: show current directory with ~
    tmux rename-window "${PWD/#$HOME/~}"
  }
  preexec() {
    # For running command: show command with arguments (first 20 chars)
    local cmd="${1[0,20]}"
    tmux rename-window "$cmd"
  }
fi

#
# Bind keys
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

bindkey "^[^[[D" backward-word
bindkey "^[^[[C" forward-word

#
# Aliases
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

# Source aliases if the file exists
[[ ! -f ~/.zsh_aliases ]] || source ~/.zsh_aliases

#
# Local Configuration
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

# Source machine-specific configurations
# This file is not version controlled and should contain:
# - Machine-specific PATH modifications
# - Company/organization-specific settings
# - Local development environment configuration
[[ ! -f ~/.zshrc.local ]] || source ~/.zshrc.local
