# PATH Setup (loaded for ALL shells)
# ═══════════════════════════════════════════════════════════════════

if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Go (XDG-compliant paths)
export GOPATH="$HOME/.local/share/go"
export GOMODCACHE="$HOME/.cache/go/mod"
[[ ":$PATH:" != *":$GOPATH/bin:"* ]] && export PATH="$GOPATH/bin:$PATH"

# Proxy Configuration
# ═══════════════════════════════════════════════════════════════════

_proxy="http://62.84.127.89:50050"
_no_proxy="localhost,127.0.0.1,.local,.ru,yandex.net,yastatic.net"
export http_proxy="$_proxy" HTTP_PROXY="$_proxy"
export https_proxy="$_proxy" HTTPS_PROXY="$_proxy"
export all_proxy="$_proxy" ALL_PROXY="$_proxy"
export no_proxy="$_no_proxy" NO_PROXY="$_no_proxy"
unset _proxy _no_proxy

# 1Password SSH Agent
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Agent shell commands
# ═══════════════════════════════════════════════════════════════════
# Claude Code and Codex run each command as `zsh -c`/`-lc` and their agents write bash, so those
# shells split words and keep `=x` and unmatched globs; zsh script files and interactive shells do not.
if [[ -n $ZSH_EXECUTION_STRING && ! -o interactive && -n $CLAUDECODE$CODEX_SHELL$CODEX_THREAD_ID ]]; then
    setopt SH_WORD_SPLIT NO_EQUALS NO_NOMATCH
fi
