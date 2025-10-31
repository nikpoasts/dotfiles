#!/bin/bash

set -euo pipefail

echo "Setting up Linux-specific configurations..."

# Install additional Linux packages if needed
# This script can be extended with Linux-specific setup tasks

# Example: Set up useful directories
mkdir -p ~/.local/bin
mkdir -p ~/.local/share

# Example: Install additional tools via apt if needed
# sudo apt install -y <package-name>

echo "Linux setup complete!"