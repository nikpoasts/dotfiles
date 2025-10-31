#!/bin/bash

set -euo pipefail

# Colors
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OS=$(uname -s)

warn() { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}"; exit 1; }

chmod +x "$SCRIPT_DIR"/{symlink.sh,mac/mac-setup.sh,linux/linux-setup.sh} 2>/dev/null || true

if [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    else
        brew update
    fi
    
    brew upgrade || warn "Some packages failed to upgrade"
    brew install --quiet stow git || warn "Some packages may already be installed"
    
    [ -f "$SCRIPT_DIR/mac/Brewfile" ] && \
        brew bundle --file="$SCRIPT_DIR/mac/Brewfile" || warn "Some Brewfile packages may already be installed"
    
    [ -f "$SCRIPT_DIR/mac/mac-setup.sh" ] && "$SCRIPT_DIR/mac/mac-setup.sh"
    
elif [ "$OS" = "Linux" ]; then
    [ "$EUID" -eq 0 ] && error "Run as regular user (not root)"
    
    sudo apt update || error "Failed to update package lists"
    sudo apt install -y stow git || error "Failed to install dependencies"
    
    [ -f "$SCRIPT_DIR/linux/apt-packages.txt" ] && \
        xargs sudo apt install -y < "$SCRIPT_DIR/linux/apt-packages.txt" || warn "Some packages may have failed"
    
    [ -f "$SCRIPT_DIR/linux/linux-setup.sh" ] && "$SCRIPT_DIR/linux/linux-setup.sh"
    
else
    error "Unsupported OS: $OS"
fi

[ -f "$SCRIPT_DIR/symlink.sh" ] || error "symlink.sh not found"
"$SCRIPT_DIR/symlink.sh"