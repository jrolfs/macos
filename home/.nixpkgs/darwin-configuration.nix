{ config, lib, pkgs, ... }:

with lib;

{
  # macOS Settings

  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 15;
  system.defaults.NSGlobalDomain.KeyRepeat = 2;
  system.defaults.NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;

  system.defaults.dock.autohide = true;
  system.defaults.dock.orientation = "bottom";
  system.defaults.dock.showhidden = true;
  system.defaults.dock.minimize-to-application = true;
  system.defaults.dock.mru-spaces = false;

  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder.QuitMenuItem = true;
  system.defaults.finder.FXEnableExtensionChangeWarning = false;

  system.defaults.trackpad.Clicking = true;
  system.defaults.trackpad.TrackpadRightClick = true;
  system.defaults.trackpad.TrackpadThreeFingerDrag = true;

  # Packages

  environment.systemPackages =
    [
      # Terminal utilities
      pkgs.ack
      pkgs.curl
      pkgs.dtach
      pkgs.fasd
      pkgs.fzf
      pkgs.htop
      pkgs.jq
      pkgs.ripgrep
      pkgs.silver-searcher
      pkgs.urlview

      # Build
      pkgs.autoconf
      pkgs.automake
      pkgs.cmake

      # Font
      pkgs.fontforge

      # Fun
      pkgs.fortune
      pkgs.figlet

      # Codecs & file support
      pkgs.ffmpeg
      pkgs.imagemagick
      pkgs.lame
      pkgs.unrar

      # Databases
      pkgs.gdbm
      pkgs.postgresql

      # Git
      pkgs.git
      pkgs.git-crypt

      # Security
      pkgs.gnupg
      (pkgs.pinentry.override { gtk2 = null; gcr = null; qt = null; })

      # Languages
      pkgs.go
      pkgs.perl

      # Development tools
      pkgs.ctags
      pkgs.html-tidy
      pkgs.httpie
      pkgs.vagrant

      # Messaging
      pkgs.weechat

      # Editors
      pkgs.neovim
      pkgs.vim-vint

      pkgs.python27Packages.neovim
      pkgs.python27Packages.powerline
      pkgs.python36Packages.neovim
      pkgs.python27Packages.pylint
      pkgs.python36Packages.pylint
      pkgs.python36Packages.websocket_client

      # Network utilities
      pkgs.mosh
      pkgs.rclone

      # Shell
      pkgs.zsh
      pkgs.tmux
      pkgs.reattach-to-user-namespace
      pkgs.terminal-notifier

      # Nix
      pkgs.nix
      pkgs.nix-repl ];

  # Nix settings

  nix.gc.automatic = true;

  nixpkgs.config.allowUnfree = true;

  services.activate-system.enable = true;
  services.nix-daemon.enable = true;

  # Use local 'nixpkgs' and 'darwin-nix' instead of channel
  nix.nixPath =
    [
      "darwin=$HOME/.nix-defexpr/darwin"
      "nixpkgs=$HOME/.nix-defexpr/nixpkgs"
      "darwin-config=$HOME/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/$USER/channels"
    ];

  # Zsh
  programs.zsh.enable = true;

  environment.etc."zshrc".text =
    let cfg = config.programs.zsh; in mkForce
      ''
        # /etc/static/zshrc
        #
        # - Read-only for ❄ Nix configuration
        # - This file is read for interactive shells
        # - Please *do not edit* this file

        # Only execute this file once per shell
        if [ -n "$NIX_ZSHRC_SOURCED" ]; then return; fi; NIX_ZSHRC_SOURCED=1

        bindkey -e

        # Add Nix bin directories to $PATH
        path=(${config.environment.systemPath} $path)

        # Environment
        ${config.system.build.setEnvironment.text}
        ${config.system.build.setAliases.text}
        ${config.environment.extraInit}

        # Add completions to Zsh function path
        for profile in ''${(z)NIX_PROFILES}; do
          fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions)
        done
      '';
}
