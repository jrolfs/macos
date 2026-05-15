# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Personal dotfiles repository managed via **homesick** (Ruby-based dotfile manager). The `home/` directory mirrors the home directory structure — homesick symlinks files from `home/` into `~/`. Sensitive files are encrypted with **git-crypt** and stored in a separate `private` repo at `$HOMESHICK_KINGDOM/private`.

## Structure

- `home/` — symlinked into `~/` by homesick (contains `.zshenv`, `.zprofile`, `.zshrc`, `.config/`, etc.)
- `home/.config/` — XDG config home (`~/.config/`), organized per-application
- Top-level directories (e.g., `vscode/`, `spicetify/`, `raycast/`) — app configs not managed via XDG, some are git submodules
- `~/` (tilde directory at repo root) — macOS-specific paths like `Library/`
- Git submodules for external themes/plugins: kitty-catppuccin, kitty-smart-scroll, kitty-grab, zinit, firefox-cascade, gruvbox-material-tridactyl, base16-tridactyl, spicetify-catppuccin, vscode

## Key Configurations

**Shell (zsh):** Entry points are `home/.zshenv` → `home/.zprofile` → `home/.zshrc` → `home/.zlogin`. Modular config lives in `home/.config/zsh/` with separate files for aliases, completions, functions, and per-tool setup (atuin, direnv, kitty, neovim, starship, etc.). Machine-specific env files use the pattern `env.<hostname>`.

**Git:** Config at `home/.config/git/config`. Uses delta as pager, GPG signing by default, git-duet for pairing. Multiple merge/diff tool configs (cursor, vscode, smerge, nvim).

**Kitty terminal:** Config at `home/.config/kitty/` with separate files for bindings, diff, grab. Custom kittens and zoom toggle script. Themes via catppuccin submodule.

**Glide browser:** TypeScript-based config at `home/.config/glide/` with its own devbox.json and pnpm-lock.yaml.

## Conventions

- **Indentation:** 2 spaces, LF line endings, UTF-8 (see `.editorconfig`)
- **Runtime versions:** Managed via **mise** (successor to asdf), activated in `.zprofile`
- **XDG compliance:** All configs use XDG base directories (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`)
- **JS/TS linting:** oxlint (`.oxlintrc.json` at repo root) — prefers `type-imports` with inline style, disallows default exports (except config files and React Router routes), uses `^_` pattern for unused vars
- **JS/TS formatting:** oxfmt (`.oxfmtrc.json` at repo root)

## Working with This Repo

There is no build system, test suite, or CI. Changes are made by editing config files directly and committing. To apply changes after editing, either re-source the relevant shell file or restart the application.

When editing zsh config, be aware of the load order: `.zshenv` (always) → `.zprofile` (login) → `.zshrc` (interactive) → `.zlogin` (login, after `.zshrc`). Environment variables and path setup belong in `.zshenv`/`.zprofile`; interactive features (aliases, completions, keybindings) belong in `.zshrc` or the modular files it sources from `home/.config/zsh/`.
