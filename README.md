# Nik's Dotfiles

I've created this repository to manage my dotfiles. I often ssh into remote servers (Linux) from my Mac. I wanted a system with modular design, cross-platform compatibility, and ease of use. So, I have designed this to meet my requirements. 

Feel free to fork and adapt for your own use. I will be maintaining this repository and adding new features as I need them. Please feel free to open an issue if you have any suggestions or find any bugs.

Special thanks to [X-AI's Grok](https://grok.com/) for accelerating the process of creating this repository. This readme was mostly done by Grok.

## Repository Structure

```
dotfiles/
├── README.md               
├── install.sh              # Main setup script (installs dependencies & symlinks)
├── symlink.sh              # Stow automation for creating symlinks
├── .stow-global-ignore     # Files to ignore when stowing
├── git/                    # Git configuration
│   ├── dot-gitconfig-work  # Work machine Git config
│   ├── dot-gitignore_global # Global Git ignore file
│   ├── dot-gitconfig       # Main .gitconfig (shared across systems)
│   └── README.md           # Git-specific notes
├── ssh/                    # SSH configuration
│   ├── dot-ssh/
│   │   └── config          # Main SSH config (becomes ~/.ssh/config)
│   └── README.md           # SSH security tips
├── terminal/               # Terminal configurations
│   ├── dot-common_commands # Common commands for both Bash and Zsh
│   ├── dot-bashrc          # Bash configuration
│   ├── dot-zshrc           # Zsh configuration
│   ├── dot-config/
│   │   └── starship.toml   # Starship prompt configuration
│   ├── ghostty.config      # Ghostty terminal emulator config
│   └── README.md           # Shell setup notes
├── mac/                    # Mac-specific configurations
│   ├── Brewfile            # Homebrew packages list
│   ├── mac-setup.sh        # Mac-specific setup script
│   ├── RectangleConfig.json # Rectangle window manager config
│   ├── karabiner.json      # Karabiner Elements keyboard config
│   └── README.md           # Mac-specific instructions
├── linux/                  # Linux-specific configurations
│   ├── apt-packages.txt    # APT packages list
│   ├── linux-setup.sh      # Linux-specific setup script
│   └── README.md           # Linux-specific instructions
└── shared/                 # Shared environment configurations
    ├── dot-profile         # .profile for environment variables
    └── README.md           # Shared config notes
```

**Note**: Files prefixed with `dot-` are automatically converted to dotfiles (e.g., `dot-gitconfig` → `.gitconfig`) by Stow's `--dotfiles` flag.

## Quick Setup (New Machine)

### Initial Setup

1. **Clone the repository:** 
   ```bash
   git clone https://github.com/nikpoasts/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Set Git remote URL:**
   ```bash
   git remote set-url origin https://github.com/nikpoasts/dotfiles.git
   ```

4. **Run the installation script:**
   ```bash
   chmod +x install.sh symlink.sh
   ./install.sh
   ```

5. **Reload your shell:**
   ```bash
   source ~/.zshrc  # or source ~/.bashrc
   ```

### What `install.sh` Does

- Detects your OS (Mac or Linux)
- Installs required dependencies (Homebrew, Stow, Git)
- Installs OS-specific packages (from Brewfile or apt-packages.txt)
- Runs OS-specific setup scripts
- Executes symlink.sh to create all necessary symlinks

## 🔗 Symlinking with GNU Stow

This repository uses [GNU Stow](https://www.gnu.org/software/stow/) to manage symlinks. Stow creates symlinks from the repo to your home directory while preserving the directory structure.

### How It Works

- **Dotfiles conversion**: Files prefixed with `dot-` are automatically converted to dotfiles using the `--dotfiles` flag (e.g., `dot-gitconfig` → `.gitconfig`)
- **Shared configs**: `stow --dotfiles git` creates `~/.gitconfig` → `~/dotfiles/git/dot-gitconfig`
- **OS-specific**: `stow --dotfiles linux` for Linux-specific configs (Mac configs are manually linked)
- **All at once**: `./symlink.sh` detects your OS and stows everything appropriately

### Manual Stow Commands

```bash
# Stow a single folder (from dotfiles directory)
stow --dotfiles git

# Restow (update existing symlinks)
stow --dotfiles -R git

# Unstow (remove symlinks)
stow --dotfiles -D git

# Dry run (preview changes)
stow --dotfiles -n git

# Restow multiple folders
stow --dotfiles -R git ssh terminal shared

# Specify directory explicitly
stow --dotfiles -d ~/dotfiles -R git
```

## 📝 Expected Symlink Locations

After running `symlink.sh`, your files will be symlinked to:

| Config File | Symlink Location |
|-------------|------------------|
| `terminal/dot-zshrc` | `~/.zshrc` |
| `terminal/dot-bashrc` | `~/.bashrc` |
| `terminal/dot-common_commands` | `~/.common_commands` |
| `terminal/dot-config/starship.toml` | `~/.config/starship.toml` |
| `terminal/ghostty.config` | `~/Library/Application Support/com.mitchellh.ghostty/config` (Mac) |
| `git/dot-gitconfig` | `~/.gitconfig` |
| `git/dot-gitignore_global` | `~/.gitignore_global` |
| `ssh/dot-ssh/config` | `~/.ssh/config` |
| `shared/dot-profile` | `~/.profile` |
| `mac/karabiner.json` | `~/.config/karabiner/karabiner.json` (Mac, manual link) |
| `mac/RectangleConfig.json` | `~/.rectangleConfig.json` (Mac, manual link) |

## 🔄 Updating Dotfiles

### On Any Already-Configured Machine

**One-liner (recommended):**
```bash
cd ~/dotfiles && git pull --rebase && ./symlink.sh && echo "Dotfiles updated!"
```

**Or use the built-in aliases** (defined in `terminal/dot-common_commands`):

```bash
# Pull latest changes + restow everything
dotup

# Restow a single folder
dotrestow git

# Preview changes before applying
dotpreview git
```

### After Editing Configs

1. Make changes in the `~/dotfiles` directory
2. Test locally with `stow --dotfiles -R <folder>` (or use `./symlink.sh` to restow everything)
3. Commit and push:
   ```bash
   cd ~/dotfiles
   git add .
   git commit -m "Update <description>"
   git push
   ```

## 🔐 SSH Configuration

**Note**: `symlink.sh` automatically sets SSH permissions after stowing. Manual setup is only needed if you stow SSH separately.


```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_* 2>/dev/null || true
chmod 700 ~/.ssh/sockets 2>/dev/null || mkdir -p ~/.ssh/sockets && chmod 700 ~/.ssh/sockets
```

## 🛠️ OS-Specific Setup

### macOS

The `mac/` directory contains:
- **Brewfile**: Run `brew bundle --file=mac/Brewfile` to install packages
- **mac-setup.sh**: Installs Mac-specific apps (Rectangle, Karabiner Elements, etc.)
- **rectangleConfig.json**: Window management configuration
- **karabiner.json**: Custom keyboard mappings

### Linux

The `linux/` directory contains:
- **apt-packages.txt**: Install with `xargs sudo apt install < linux/apt-packages.txt`
- **linux-setup.sh**: Linux-specific package installations and configurations

## 💡 Tips & Best Practices

### Backup First
Before running on a new machine, backup existing configs:
```bash
tar -czf ~/dotfiles_backup.tar.gz ~/.*config ~/.ssh ~/.gitconfig 2>/dev/null
```

### Test Before Committing
Use dry-run to preview changes:
```bash
stow --dotfiles -n -v git  # Shows what would happen
```

### Git Best Practices
- Commit often with descriptive messages
- Use branches for testing: `git checkout -b test-feature`
- Never commit sensitive data (SSH keys, tokens, passwords)

### Cross-Platform Compatibility
- Use `$HOME` instead of hardcoded paths
- Use OS detection in scripts: `if [[ "$OSTYPE" == "darwin"* ]]; then`
- Keep shared configs in root directories, OS-specific in `mac/` or `linux/`
- Use `dot-` prefix for files that should become dotfiles (handled by `--dotfiles` flag)

## 🐛 Troubleshooting

### Stow Conflicts
If you get "file exists" errors:
```bash
# Back up the existing file
mv ~/.gitconfig ~/.gitconfig.bak

# Then stow (from dotfiles directory)
cd ~/dotfiles
stow --dotfiles git
```

### Permission Issues
If symlinks have wrong permissions:
```bash
chmod +x ~/dotfiles/install.sh ~/dotfiles/symlink.sh
```

### Reload Not Working
After symlinking terminal configs:
```bash
# For bash
source ~/.bashrc

# For zsh
source ~/.zshrc

# Or open a new terminal window
```

## 📚 Resources & Inspiration

- [Holman's Dotfiles](https://github.com/holman/dotfiles)
- [Managing Dotfiles with Stow](https://www.gnu.org/software/stow/)
- [Homebrew Installation](https://brew.sh/)
- [Dotfiles Guide Video](https://www.youtube.com/watch?v=oR_B2gQDVf4)

## 📄 License

This is a personal dotfiles repository. Feel free to fork and adapt for your own use.