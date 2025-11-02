#!/bin/bash

set -euo pipefail

# Colors
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS=$(uname -s)
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
CONFLICTS=()

# Check if stow supports --dotfiles flag
check_stow() {
    if ! command -v stow >/dev/null 2>&1; then
        return 1
    fi
    # Test if --dotfiles flag is supported
    stow --help 2>/dev/null | grep -q "dotfiles" 2>/dev/null || return 1
    return 0
}

# Manual symlink creation fallback
manual_stow_package() {
    local package=$1
    local src_dir="$SCRIPT_DIR/$package"
    local dest_dir="$HOME"
    
    find "$src_dir" -type f \( -name "dot-*" -o \( ! -name ".*" -a ! -name "README.md" -a ! -name ".stowignore" \) \) 2>/dev/null | while read -r src_file; do
        local rel_path="${src_file#$src_dir/}"
        local filename=$(basename "$rel_path")
        local dir_path=$(dirname "$rel_path")
        
        # Skip if file is in a dot-* directory (handled separately)
        [[ "$rel_path" =~ ^dot-[^/]+/ ]] && continue
        
        # Convert dot-* files to .* files
        if [[ "$filename" =~ ^dot- ]]; then
            local dotfile_name=".${filename#dot-}"
            if [ "$dir_path" = "." ]; then
                local dest_file="$dest_dir/$dotfile_name"
            else
                local dest_file="$dest_dir/$dir_path/$dotfile_name"
            fi
        else
            if [ "$dir_path" = "." ]; then
                local dest_file="$dest_dir/$filename"
            else
                local dest_file="$dest_dir/$rel_path"
            fi
        fi
        
        [ -L "$dest_file" ] && rm "$dest_file" 2>/dev/null || true
        mkdir -p "$(dirname "$dest_file")"
        ln -sf "$src_file" "$dest_file"
    done
    
    # Handle subdirectories (like dot-ssh/config)
    find "$src_dir" -type d -name "dot-*" 2>/dev/null | while read -r src_dir_path; do
        local rel_dir="${src_dir_path#$src_dir/}"
        local dirname=$(basename "$rel_dir")
        local parent_dir=$(dirname "$rel_dir")
        
        if [[ "$dirname" =~ ^dot- ]]; then
            local dot_dirname=".${dirname#dot-}"
            
            if [ "$parent_dir" = "." ]; then
                local dest_dir_path="$dest_dir/$dot_dirname"
            else
                local dest_dir_path="$dest_dir/$parent_dir/$dot_dirname"
            fi
            
            find "$src_dir_path" -type f 2>/dev/null | while read -r src_file; do
                local file_rel_path="${src_file#$src_dir_path/}"
                local dest_file="$dest_dir_path/$file_rel_path"
                
                mkdir -p "$(dirname "$dest_file")"
                [ -L "$dest_file" ] && rm "$dest_file" 2>/dev/null || true
                ln -sf "$src_file" "$dest_file"
            done
        fi
    done
}

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
    
    # Use manual fallback if stow is not available
    if ! check_stow; then
        manual_stow_package "$package"
        return 0
    fi
    
    # Try stow with --dotfiles flag
    if [ -n "$ignore_opts" ]; then
        stow --dotfiles $ignore_opts -R -d "$SCRIPT_DIR" "$package" 2>/dev/null || \
        stow --dotfiles $ignore_opts -d "$SCRIPT_DIR" "$package" 2>/dev/null || \
        manual_stow_package "$package"
    else
        stow --dotfiles -R -d "$SCRIPT_DIR" "$package" 2>/dev/null || \
        stow --dotfiles -d "$SCRIPT_DIR" "$package" 2>/dev/null || \
        manual_stow_package "$package"
    fi
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
# Check stow availability
if ! command -v stow >/dev/null 2>&1; then
    echo -e "${RED}Error: stow not installed${NC}"
    echo "  macOS: brew install stow"
    echo "  Linux: sudo apt install stow"
    echo "  Continuing with manual symlink creation..."
fi

# Copy global ignore file if it exists
[ -f "$SCRIPT_DIR/.stow-global-ignore" ] && \
    cp "$SCRIPT_DIR/.stow-global-ignore" "$HOME/.stow-global-ignore" 2>/dev/null || true

# Backup conflicts
for package in terminal git shared ssh; do
    [ -d "$SCRIPT_DIR/$package" ] && backup_conflicts "$package"
done
check_conflicts

# Stow packages
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

# Show backups if any were created
[ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ] && \
    echo -e "${YELLOW}Backups saved to: $BACKUP_DIR${NC}"
