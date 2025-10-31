#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up macOS-specific configurations..."

# Install Mac apps via Homebrew if not already installed
if command -v brew >/dev/null 2>&1; then
    echo "Installing macOS applications..."
    brew install --cask rectangle karabiner-elements ghostty raycast sublime-text || true
    
    # Note: Services are typically auto-started by macOS or the apps themselves
    # Uncomment if you need to manually start services:
    # brew services start orbstack
    # brew services start rectangle
    # brew services start karabiner-elements
else
    echo "Warning: Homebrew not found. Please install Homebrew first."
    exit 1
fi

echo "macOS setup complete!"
