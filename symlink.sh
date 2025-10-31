#!/bin/bash

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS=$(uname -s)
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
CONFLICTS=()

# Get package files: returns comma-separated list of files for a package
get_package_files() {
    case "$1" in
        ssh) echo ".ssh/config" ;;
        terminal) echo ".zshrc,.bashrc,.common_commands" ;;
        git) echo ".gitconfig,.gitignore_global" ;;
        shared) echo ".profile" ;;
        *) echo "" ;;
    esac
}

backup_file() {
    local src=$1 dest=$2
    [ -f "$src" ] && [ ! -L "$src" ] && {
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        CONFLICTS+=("$src")
    }
}

backup_conflicts() {
    local package=$1 files
    files=$(get_package_files "$package")
    [ -z "$files" ] && return
    
    IFS=',' read -ra file_list <<< "$files"
    for file in "${file_list[@]}"; do
        backup_file "$HOME/$file" "$BACKUP_DIR/$file"
    done
    
    # Handle terminal dot-config files
    [ "$package" = "terminal" ] && [ -d "$SCRIPT_DIR/terminal/dot-config" ] && \
        find "$SCRIPT_DIR/terminal/dot-config" -type f | while read -r src_file; do
            rel_path="${src_file#$SCRIPT_DIR/terminal/dot-config/}"
            backup_file "$HOME/.config/$rel_path" "$BACKUP_DIR/.config/$rel_path"
        done
}

check_conflicts() {
    [ ${#CONFLICTS[@]} -eq 0 ] && return 0
    
    echo -e "${YELLOW}Conflicts detected (backed up to $BACKUP_DIR):${NC}"
    for conflict in "${CONFLICTS[@]}"; do
        echo -e "  ${YELLOW}- $conflict${NC}"
    done
    
    for conflict in "${CONFLICTS[@]}"; do
        [ -e "$conflict" ] && [ ! -L "$conflict" ] && {
            echo -e "${RED}Error: Conflicts exist. Resolve before continuing.${NC}"
            exit 1
        }
    done
    echo ""
}

stow_package() {
    local package=$1 ignore_opts=${2:-}
    stow --dotfiles ${ignore_opts} -R -d "$SCRIPT_DIR" "$package" 2>/dev/null || \
        stow --dotfiles ${ignore_opts} -d "$SCRIPT_DIR" "$package" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Failed to stow $package${NC}"
        }
}

symlink_file() {
    local src=$1 dest=$2
    [ -L "$dest" ] && rm "$dest"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

setup_ssh() {
    [ ! -d "$SCRIPT_DIR/ssh" ] && return
    mkdir -p "$HOME/.ssh"/{config.d,sockets}
    [ -f "$SCRIPT_DIR/ssh/dot-ssh/config" ] && \
        symlink_file "$SCRIPT_DIR/ssh/dot-ssh/config" "$HOME/.ssh/config"
    chmod 700 "$HOME/.ssh"
    [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/id_"* 2>/dev/null || true
    chmod 700 "$HOME/.ssh"/{sockets,config.d} 2>/dev/null || true
    chmod 600 "$HOME/.ssh/config.d/"* 2>/dev/null || true
}

setup_config() {
    [ ! -d "$SCRIPT_DIR/terminal/dot-config" ] && return
    mkdir -p "$HOME/.config"
    find "$SCRIPT_DIR/terminal/dot-config" -type f | while read -r src_file; do
        rel_path="${src_file#$SCRIPT_DIR/terminal/dot-config/}"
        symlink_file "$src_file" "$HOME/.config/$rel_path"
    done
}

setup_macos() {
    [ "$OS" != "Darwin" ] && return
    [ -f "$SCRIPT_DIR/mac/karabiner.json" ] && {
        mkdir -p "$HOME/.config/karabiner"
        symlink_file "$SCRIPT_DIR/mac/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    }
    [ -f "$SCRIPT_DIR/terminal/ghostty.config" ] && {
        mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
        symlink_file "$SCRIPT_DIR/terminal/ghostty.config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
    }
    [ -f "$SCRIPT_DIR/mac/RectangleConfig.json" ] && \
        symlink_file "$SCRIPT_DIR/mac/RectangleConfig.json" "$HOME/.rectangleConfig.json"
}

setup_linux() {
    [ "$OS" != "Linux" ] && return
    [ -d "$SCRIPT_DIR/linux" ] && stow_package linux
}

# Main execution
if ! command -v stow >/dev/null 2>&1; then
    echo -e "${RED}Error: stow not installed${NC}"
    echo "  macOS: brew install stow"
    echo "  Linux: sudo apt install stow"
    exit 1
fi

[ -f "$SCRIPT_DIR/.stow-global-ignore" ] && \
    cp "$SCRIPT_DIR/.stow-global-ignore" "$HOME/.stow-global-ignore"

for package in terminal git shared ssh; do
    [ -d "$SCRIPT_DIR/$package" ] && backup_conflicts "$package"
done
check_conflicts

for package in terminal git shared; do
    [ -d "$SCRIPT_DIR/$package" ] && {
        if [ "$package" = "terminal" ] && [ -d "$SCRIPT_DIR/terminal/dot-config" ]; then
            stow_package "$package" "--ignore=dot-config"
        else
            stow_package "$package"
        fi
    }
done

setup_config
setup_ssh
setup_macos
setup_linux

[ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ] && \
    echo -e "${GREEN}Backups: $BACKUP_DIR${NC}"
