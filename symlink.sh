#!/bin/bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Resolve script directory reliably
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${GREEN}Using dotfiles directory: $SCRIPT_DIR${NC}"

OS=$(uname -s)

# Check if stow is installed
if ! command -v stow >/dev/null 2>&1; then
    echo -e "${YELLOW}Error: stow is not installed. Please install it first.${NC}"
    echo "  macOS: brew install stow"
    echo "  Linux: sudo apt install stow"
    exit 1
fi

# Copy global stow ignore
if [ -f "$SCRIPT_DIR/.stow-global-ignore" ]; then
    cp "$SCRIPT_DIR/.stow-global-ignore" "$HOME/.stow-global-ignore"
fi

# Create a single backup directory for this run
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Array to track conflicts
CONFLICTS=()

# Function to detect and backup conflicting files (without deleting them)
backup_conflicting_paths() {
    local package=$1
    
    # Define potential conflicts for each package
    case "$package" in
        ssh)
            # ssh/dot-ssh/config becomes ~/.ssh/config
            # Only handle the config file, preserve the rest of .ssh directory
            if [ -f "$HOME/.ssh/config" ] && [ ! -L "$HOME/.ssh/config" ]; then
                mkdir -p "$BACKUP_DIR/.ssh"
                echo -e "${YELLOW}  Backing up existing $HOME/.ssh/config to $BACKUP_DIR/.ssh/config${NC}"
                cp "$HOME/.ssh/config" "$BACKUP_DIR/.ssh/config"
                CONFLICTS+=("$HOME/.ssh/config")
            fi
            ;;
        terminal)
            # terminal/dot-config/ files become ~/.config/ files
            # Only check if .config exists as a file (should be a directory)
            if [ -f "$HOME/.config" ]; then
                mkdir -p "$BACKUP_DIR"
                echo -e "${YELLOW}  Backing up existing $HOME/.config (file) to $BACKUP_DIR/.config${NC}"
                cp "$HOME/.config" "$BACKUP_DIR/.config"
                CONFLICTS+=("$HOME/.config")
            fi
            # Check for all files in dot-config that would conflict
            if [ -d "$SCRIPT_DIR/terminal/dot-config" ]; then
                while IFS= read -r src_file; do
                    # Get relative path from dot-config directory
                    rel_path="${src_file#$SCRIPT_DIR/terminal/dot-config/}"
                    dest_file="$HOME/.config/$rel_path"
                    if [ -f "$dest_file" ] && [ ! -L "$dest_file" ]; then
                        mkdir -p "$BACKUP_DIR/.config/$(dirname "$rel_path")"
                        echo -e "${YELLOW}  Backing up existing $dest_file to $BACKUP_DIR/.config/$rel_path${NC}"
                        cp "$dest_file" "$BACKUP_DIR/.config/$rel_path"
                        CONFLICTS+=("$dest_file")
                    fi
                done < <(find "$SCRIPT_DIR/terminal/dot-config" -type f)
            fi
            # Also check for .zshrc, .bashrc, .common_commands
            for file in .zshrc .bashrc .common_commands; do
                if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                    mkdir -p "$BACKUP_DIR"
                    echo -e "${YELLOW}  Backing up existing $HOME/$file to $BACKUP_DIR/$file${NC}"
                    cp "$HOME/$file" "$BACKUP_DIR/$file"
                    CONFLICTS+=("$HOME/$file")
                fi
            done
            ;;
        git)
            # git/dot-gitconfig becomes ~/.gitconfig
            if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
                mkdir -p "$BACKUP_DIR"
                echo -e "${YELLOW}  Backing up existing $HOME/.gitconfig to $BACKUP_DIR/.gitconfig${NC}"
                cp "$HOME/.gitconfig" "$BACKUP_DIR/.gitconfig"
                CONFLICTS+=("$HOME/.gitconfig")
            fi
            if [ -f "$HOME/.gitignore_global" ] && [ ! -L "$HOME/.gitignore_global" ]; then
                mkdir -p "$BACKUP_DIR"
                echo -e "${YELLOW}  Backing up existing $HOME/.gitignore_global to $BACKUP_DIR/.gitignore_global${NC}"
                cp "$HOME/.gitignore_global" "$BACKUP_DIR/.gitignore_global"
                CONFLICTS+=("$HOME/.gitignore_global")
            fi
            ;;
        shared)
            # shared/dot-profile becomes ~/.profile
            if [ -f "$HOME/.profile" ] && [ ! -L "$HOME/.profile" ]; then
                mkdir -p "$BACKUP_DIR"
                echo -e "${YELLOW}  Backing up existing $HOME/.profile to $BACKUP_DIR/.profile${NC}"
                cp "$HOME/.profile" "$BACKUP_DIR/.profile"
                CONFLICTS+=("$HOME/.profile")
            fi
            ;;
    esac
}

# Function to check if conflicts still exist and prompt user
check_and_prompt_conflicts() {
    if [ ${#CONFLICTS[@]} -eq 0 ]; then
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  Conflicts detected!${NC}"
    echo -e "${YELLOW}The following files conflict with dotfiles and have been backed up:${NC}"
    for conflict in "${CONFLICTS[@]}"; do
        echo -e "  ${YELLOW}- $conflict${NC}"
    done
    echo ""
    echo -e "${YELLOW}Backups are located in: $BACKUP_DIR${NC}"
    echo ""
    echo -e "${YELLOW}Please manually resolve these conflicts by:${NC}"
    echo -e "${YELLOW}  1. Reviewing the backed up files in $BACKUP_DIR${NC}"
    echo -e "${YELLOW}  2. Removing or renaming the conflicting files listed above${NC}"
    echo -e "${YELLOW}  3. Running this script again${NC}"
    echo ""
    echo -e "${YELLOW}This script will not automatically delete your existing files.${NC}"
    echo ""
    
    # Check if conflicts still exist
    local still_conflicts=0
    for conflict in "${CONFLICTS[@]}"; do
        if [ -e "$conflict" ] && [ ! -L "$conflict" ]; then
            still_conflicts=1
            break
        fi
    done
    
    if [ $still_conflicts -eq 1 ]; then
        echo -e "${YELLOW}❌ Conflicts still exist. Please resolve them before continuing.${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Conflicts have been resolved. Continuing...${NC}"
        echo ""
    fi
}

# -------------------------------------------------
# Detect and backup all conflicts first
# -------------------------------------------------
echo -e "${GREEN}Checking for conflicts...${NC}"
for package in terminal git shared ssh; do
    if [ -d "$SCRIPT_DIR/$package" ]; then
        # Backup conflicting files (without deleting them)
        backup_conflicting_paths "$package"
    fi
done

# Check for conflicts before proceeding - exit if conflicts exist
check_and_prompt_conflicts

# -------------------------------------------------
# Stow shared packages – now with --dotfiles
# -------------------------------------------------
echo -e "${GREEN}Stowing shared packages...${NC}"
for package in terminal git shared; do
    if [ -d "$SCRIPT_DIR/$package" ]; then
        echo "  Stowing $package..."
        # For terminal package, exclude dot-config directory (handled manually)
        if [ "$package" = "terminal" ]; then
            # Temporarily rename dot-config to exclude it from stow
            if [ -d "$SCRIPT_DIR/terminal/dot-config" ]; then
                mv "$SCRIPT_DIR/terminal/dot-config" "$SCRIPT_DIR/terminal/.dot-config-backup"
            fi
            # Try restow first, if it fails, try unstow then stow
            if ! stow --dotfiles -R -d "$SCRIPT_DIR" "$package" 2>/dev/null; then
                # If restow fails, try unstowing first (ignore errors), then stow
                stow --dotfiles -D -d "$SCRIPT_DIR" "$package" 2>/dev/null || true
                stow --dotfiles -d "$SCRIPT_DIR" "$package" || {
                    echo -e "${YELLOW}Warning: Failed to stow $package${NC}"
                }
            fi
            # Restore dot-config directory
            if [ -d "$SCRIPT_DIR/terminal/.dot-config-backup" ]; then
                mv "$SCRIPT_DIR/terminal/.dot-config-backup" "$SCRIPT_DIR/terminal/dot-config"
            fi
        else
            # Try restow first, if it fails, try unstow then stow
            if ! stow --dotfiles -R -d "$SCRIPT_DIR" "$package" 2>/dev/null; then
                # If restow fails, try unstowing first (ignore errors), then stow
                stow --dotfiles -D -d "$SCRIPT_DIR" "$package" 2>/dev/null || true
                stow --dotfiles -d "$SCRIPT_DIR" "$package" || {
                    echo -e "${YELLOW}Warning: Failed to stow $package${NC}"
                }
            fi
        fi
    else
        echo -e "${YELLOW}Warning: Directory $package not found, skipping${NC}"
    fi
done

# -------------------------------------------------
# .config directory handling (manual, preserves .config directory structure)
# Only symlink files from dot-config, don't replace entire .config directory
# -------------------------------------------------
if [ -d "$SCRIPT_DIR/terminal/dot-config" ]; then
    echo -e "${GREEN}Handling .config directory...${NC}"
    # Ensure .config directory exists
    mkdir -p "$HOME/.config"
    
    # Symlink each file from dot-config into .config (conflicts already checked and resolved)
    find "$SCRIPT_DIR/terminal/dot-config" -type f | while read -r src_file; do
        # Get relative path from dot-config directory
        rel_path="${src_file#$SCRIPT_DIR/terminal/dot-config/}"
        dest_file="$HOME/.config/$rel_path"
        
        # Check if destination already exists as a non-symlink file (should have been backed up already)
        if [ -f "$dest_file" ] && [ ! -L "$dest_file" ]; then
            echo -e "${YELLOW}  Warning: $dest_file exists but wasn't backed up, skipping${NC}"
            continue
        fi
        
        # Remove existing symlink if it exists (to update it)
        [ -L "$dest_file" ] && rm "$dest_file"
        
        # Create parent directory if needed
        mkdir -p "$(dirname "$dest_file")"
        
        # Create symlink
        ln -sf "$src_file" "$dest_file"
        echo "  Linked $rel_path"
    done
fi

# -------------------------------------------------
# SSH config handling (manual, preserves .ssh directory structure)
# -------------------------------------------------
if [ -d "$SCRIPT_DIR/ssh" ]; then
    echo -e "${GREEN}Handling SSH config...${NC}"
    # Ensure .ssh directory exists
    mkdir -p "$HOME/.ssh"
    
    # Symlink only the config file (conflicts already checked and resolved)
    if [ -f "$SCRIPT_DIR/ssh/dot-ssh/config" ]; then
        # Remove existing symlink if it exists (to update it)
        [ -L "$HOME/.ssh/config" ] && rm "$HOME/.ssh/config"
        # Create symlink (conflict check already ensured no regular file exists)
        ln -sf "$SCRIPT_DIR/ssh/dot-ssh/config" "$HOME/.ssh/config"
        echo "  Linked SSH config"
    fi
    
    # Ensure config.d and sockets directories exist (but don't replace if they already exist)
    mkdir -p "$HOME/.ssh/config.d"
    mkdir -p "$HOME/.ssh/sockets"
fi

# -------------------------------------------------
# SSH permissions (runs after stow creates .ssh)
# -------------------------------------------------
if [ -d "$HOME/.ssh" ]; then
    echo -e "${GREEN}Setting SSH permissions...${NC}"
    chmod 700 "$HOME/.ssh"
    [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/id_"* 2>/dev/null || true
    mkdir -p "$HOME/.ssh/sockets" && chmod 700 "$HOME/.ssh/sockets"
    mkdir -p "$HOME/.ssh/config.d" && chmod 700 "$HOME/.ssh/config.d"
    chmod 600 "$HOME/.ssh/config.d/"* 2>/dev/null || true
fi

# -------------------------------------------------
# macOS-specific manual links
# -------------------------------------------------
if [ "$OS" = "Darwin" ]; then
    echo -e "${GREEN}Configuring macOS-specific settings...${NC}"

    # Karabiner
    if [ -f "$SCRIPT_DIR/mac/karabiner.json" ]; then
        mkdir -p "$HOME/.config/karabiner"
        ln -sf "$SCRIPT_DIR/mac/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
        echo "  Linked Karabiner config"
    fi

    # Ghostty
    if [ -f "$SCRIPT_DIR/terminal/ghostty.config" ]; then
        mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
        ln -sf "$SCRIPT_DIR/terminal/ghostty.config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
        echo "  Linked Ghostty config"
    fi

    # Rectangle
    if [ -f "$SCRIPT_DIR/mac/RectangleConfig.json" ]; then
        ln -sf "$SCRIPT_DIR/mac/RectangleConfig.json" "$HOME/.rectangleConfig.json"
        echo "  Linked Rectangle config"
    fi

elif [ "$OS" = "Linux" ]; then
    echo -e "${GREEN}Stowing Linux-specific configs...${NC}"
    if [ -d "$SCRIPT_DIR/linux" ]; then
        # Try restow first, if it fails, try unstow then stow
        if ! stow --dotfiles -R -d "$SCRIPT_DIR" linux 2>/dev/null; then
            # If restow fails, try unstowing first (ignore errors), then stow
            stow --dotfiles -D -d "$SCRIPT_DIR" linux 2>/dev/null || true
            stow --dotfiles -d "$SCRIPT_DIR" linux || {
                echo -e "${YELLOW}Warning: Failed to stow linux configs${NC}"
            }
        fi
    fi
else
    echo -e "${YELLOW}Warning: Unsupported OS: $OS${NC}"
    echo "  Continuing with shared packages only..."
fi

# Show backup directory info if backups were created
if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo -e "${GREEN}Backups created in: $BACKUP_DIR${NC}"
fi

echo -e "${GREEN}Symlinking complete!${NC}"
