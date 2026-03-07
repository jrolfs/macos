# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A macOS dotfiles repository managed via [Homeshick](https://github.com/andsens/homeshick). Files under `home/` are symlinked into `$HOME` by Homeshick. System configuration is managed declaratively through **nix-darwin**.

## Key Commands

```bash
# Apply nix-darwin configuration (rebuilds system packages, defaults, services, Homebrew, etc.)
sudo -E darwin-rebuild switch --show-trace

# Shorthand alias (defined in home/.zshrc.darwin)
nix-switch

# Apply custom app icons
icn    # or: (cd $HOMESHICK_KINGDOM/macos/icons && sudo ./apply.sh)

# Mackup backup/restore (syncs app preferences via file_system engine)
mkbk   # backup
mkrs   # restore
```

## Architecture

### nix-darwin Configuration (`home/.nixpkgs/`)

The entry point is `darwin-configuration.nix`, which imports:

- **`homebrew.nix`** — Homebrew casks, Mac App Store apps, and taps. Supports `NIX_MACOS_EXCLUDE_CASKS` env var (comma-separated) to skip specific apps (e.g. for org-managed devices). Cleanup mode is `zap` (removes unmanaged casks).
- **`defaults.nix`** — macOS system preferences (Dock, Finder, trackpad, keyboard, NSGlobalDomain)
- **`daemons.nix`** — launchd user agents (currently Hammerspoon)
- **`icons.nix`** — Nix-built `icon-customizer` script that applies custom `.icns` files to apps
- **`fileicon.nix`** — Packages the `fileicon` CLI tool from source
- **`overlays.nix`** — Nixpkgs overlays (darwin-zsh-completions)

### Git Submodules

- `nix-darwin/` — Fork of nix-darwin (jrolfs/nix-darwin)
- `nixpkgs/` — Fork of nixpkgs (jrolfs/nixpkgs)

These are pointed at via `NIX_PATH` in `.zshrc.darwin`.

### Custom App Icons (`icons/`)

- `icons/assets/` (symlinked as `icons/big-sur/`) contains `.icns` files named to match application names
- `icons/apply.sh` uses `fd` + `fileicon` to apply icons to `/Applications/*.app`
- Requires `sudo` for some apps

### Hammerspoon (`home/.hammerspoon/`)

Lua-based macOS automation. Modules in `modules/`:
- `autohide` — Auto-hides specific apps when they lose focus
- `finder` — Copy current Finder path
- `utilities` — Hyper key binding helpers (right option key mapped to Hyper via Karabiner)

### Karabiner Elements (`home/.config/karabiner/`)

Key remappings:
- Caps Lock → Right Control
- Right Control alone → Escape
- Right Option → Hyper key (Ctrl+Option+Cmd+Shift), alone → Ctrl+Option+A
- Fn+HJKL → Arrow keys (vim-style navigation)
- Left Option+Tab → Toggle kitty visibility
- Left Option+Backtick → Toggle Obsidian visibility

### Other Dotfiles

- `home/.skhdrc` — skhd hotkey daemon config (uses chunkc tiling, currently disabled)
- `home/.mackup.cfg` — Mackup config using file_system engine for app preference sync
- `home/.config/zsh/` — Shell helpers and `ghr` function (GitHub CLI → Raycast integration)
- `home/.local/share/raycast/` — Raycast helper scripts
- `automator/` — macOS Automator workflows (iPad mirroring, YouTube PiP)
- `vscodium/` — Nix flake for building VSCodium with extensions

## Nix Conventions

- Configuration uses the nix-darwin module system (not flakes for the main config)
- `nixpkgs.config.allowUnfree = true` and `allowBroken = true` are set
- Homebrew cleanup is set to `zap` — any cask not listed will be removed on rebuild
- Touch ID for sudo is enabled via `security.pam.services.sudo_local.touchIdAuth`
