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
# ZSH / Powerlevel10k
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /opt/homebrew/opt/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#
# Utilities
# #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide
eval "$(zoxide init zsh)"

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
