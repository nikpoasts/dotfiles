#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print colored messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
OS=$(uname -s)

info "Detected OS: $OS"
info "Installing dotfiles from: $SCRIPT_DIR"

# Make scripts executable
chmod +x "$SCRIPT_DIR/symlink.sh" "$SCRIPT_DIR/mac/mac-setup.sh" "$SCRIPT_DIR/linux/linux-setup.sh" 2>/dev/null || true

if [ "$OS" = "Darwin" ]; then  # Mac
    info "Setting up macOS..."
    
    # Install or update Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for current session
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        info "Updating Homebrew..."
        brew update
    fi
    
    info "Upgrading existing packages..."
    brew upgrade || warn "Some packages failed to upgrade (this is usually okay)"
    
    info "Installing dependencies..."
    brew install --quiet stow git || warn "Some packages may already be installed"
    
    if [ -f "$SCRIPT_DIR/mac/Brewfile" ]; then
        info "Installing packages from Brewfile..."
        brew bundle --file="$SCRIPT_DIR/mac/Brewfile" || warn "Some Brewfile packages may already be installed"
    fi
    
    if [ -f "$SCRIPT_DIR/mac/mac-setup.sh" ]; then
        info "Running macOS-specific setup..."
        "$SCRIPT_DIR/mac/mac-setup.sh"
    fi
    
elif [ "$OS" = "Linux" ]; then
    info "Setting up Linux..."
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        error "Please run this script as a regular user (not root). It will prompt for sudo when needed."
        exit 1
    fi
    
    info "Updating package lists..."
    sudo apt update || { error "Failed to update package lists"; exit 1; }
    
    info "Installing dependencies..."
    sudo apt install -y stow git || { error "Failed to install dependencies"; exit 1; }
    
    if [ -f "$SCRIPT_DIR/linux/apt-packages.txt" ]; then
        info "Installing packages from apt-packages.txt..."
        xargs sudo apt install -y < "$SCRIPT_DIR/linux/apt-packages.txt" || warn "Some packages may have failed to install"
    fi
    
    if [ -f "$SCRIPT_DIR/linux/linux-setup.sh" ]; then
        info "Running Linux-specific setup..."
        "$SCRIPT_DIR/linux/linux-setup.sh"
    fi
    
else
    error "Unsupported OS: $OS"
    exit 1
fi

# Symlink with Stow (run from dotfiles root)
info "Creating symlinks..."
if [ -f "$SCRIPT_DIR/symlink.sh" ]; then
    "$SCRIPT_DIR/symlink.sh"
else
    error "symlink.sh not found!"
    exit 1
fi

info "Setup complete!"
info "Please restart your shell or run: source ~/.zshrc  # or source ~/.bashrc"