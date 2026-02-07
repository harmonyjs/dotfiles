# PATH Setup (loaded for ALL shells)
# ═══════════════════════════════════════════════════════════════════

eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
. "$HOME/.cargo/env"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"

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
