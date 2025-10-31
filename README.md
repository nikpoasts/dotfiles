# Nik's Dotfiles

I've created this repository to manage my dotfiles. I often ssh into remote servers (Linux) from my Mac. I wanted a system with modular design, cross-platform compatibility, and ease of use. So, I have designed this to meet my requirements. 

Feel free to fork and adapt for your own use. I will be maintaining this repository and adding new features as I need them. Please feel free to open an issue if you have any suggestions or find any bugs.

Special thanks to [X-AI's Grok](https://grok.com/) and [Cursor's Composer 1](https://www.cursor.com/) for accelerating the process of creating this repository.

## Setup

On a new machine, just run:

```bash
git clone https://github.com/nikpoasts/dotfiles.git ~/dotfiles
cd ~/dotfiles
git remote set-url origin https://github.com/nikpoasts/dotfiles.git
chmod +x install.sh symlink.sh
./install.sh
source ~/.zshrc  # or source ~/.bashrc
```

The `install.sh` script handles everything: detects your OS, installs dependencies, sets up packages, and creates all the symlinks.

## How It Works

Uses [GNU Stow](https://www.gnu.org/software/stow/) to manage symlinks. Files prefixed with `dot-` automatically become dotfiles (e.g., `dot-gitconfig` → `.gitconfig`). The `symlink.sh` script detects your OS and stows everything appropriately.

**Quick commands:**
```bash
# Update everything
cd ~/dotfiles && git pull --rebase && ./symlink.sh

# Or use aliases (from dot-common_commands)
dotup              # Pull + restow everything
dotrestow git      # Restow a single folder
dotpreview git     # Preview changes

# Manual stow commands
stow --dotfiles git           # Stow a folder
stow --dotfiles -R git        # Restow (update)
stow --dotfiles -D git        # Unstow (remove)
stow --dotfiles -n git        # Dry run
```

## Structure

```
dotfiles/
├── install.sh, symlink.sh
├── git/          → ~/.gitconfig, ~/.gitignore_global
├── ssh/          → ~/.ssh/config
├── terminal/     → ~/.zshrc, ~/.bashrc, ~/.config/starship.toml
├── mac/          → Brewfile, Rectangle, Karabiner configs
├── linux/        → apt-packages.txt, linux-setup.sh
└── shared/       → ~/.profile
```

## Updating

After editing configs, test and commit:
```bash
cd ~/dotfiles
stow --dotfiles -R git  # or ./symlink.sh for everything
git add .
git commit -m "Update <description>"
git push
```

## Troubleshooting

**File exists errors?** Backup and restow:
```bash
mv ~/.gitconfig ~/.gitconfig.bak
cd ~/dotfiles && stow --dotfiles git
```

**Configs not loading?** Reload your shell:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

**SSH permissions:** `symlink.sh` handles this automatically, but if you stow SSH separately:
```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/config
```

## Resources

- [Holman's Dotfiles](https://github.com/holman/dotfiles)
- [Managing Dotfiles with Stow](https://www.gnu.org/software/stow/)
- [Dotfiles Guide Video](https://www.youtube.com/watch?v=oR_B2gQDVf4)