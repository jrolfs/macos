{ config, lib, pkgs, ... }:

{
  #
  # macOS Settings

  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
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

  environment.systemPackages =
    [
      # Terminal utilities
      pkgs.ack
      pkgs.dtach
      pkgs.fasd
      pkgs.fzf
      pkgs.jq
      pkgs.silver-searcher

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
      pkgs.pinentry

      # Languages
      pkgs.go
      pkgs.luajit
      pkgs.perl

      # Development tools
      pkgs.vagrant

      # Messaging
      pkgs.irssi

      # Editors
      pkgs.neovim
      pkgs.vim-vint
      pkgs.python27Packages.neovim
      pkgs.python27Packages.powerline
      pkgs.python36Packages.neovim
      pkgs.python27Packages.pylint
      pkgs.python36Packages.pylint

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

  # Output zshrc
  programs.zsh.enable = true;

  # Hook into launchd
  services.activate-system.enable = true;

  # Allow "unfree" packages
  nixpkgs.config.allowUnfree = true;

  # Use local 'nixpkgs' and 'darwin-nix' instead of channel
  nix.nixPath =
    [
      "darwin=$HOME/.nix-defexpr/darwin"
      "nixpkgs=$HOME/.nix-defexpr/nixpkgs"
      "darwin-config=$HOME/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/$USER/channels"
    ];
}
