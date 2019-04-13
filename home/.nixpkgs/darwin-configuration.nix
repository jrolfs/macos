{ config, lib, pkgs, ... }:

let overlays = import ./overlays.nix; in
{
  # macOS Settings

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "bottom";
      showhidden = true;
      minimize-to-application = true;
      mineffect = "scale";
      launchanim = true;
      show-process-indicators = true;
      tilesize = 48;
      static-only = false;
      mru-spaces = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      QuitMenuItem = true;
    };
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = true;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };
  };

  # Packages

  environment.systemPackages =
    [
      # Terminal utilities
      pkgs.ack
      pkgs.asciinema
      pkgs.curl
      pkgs.dtach
      pkgs.fasd
      pkgs.fd
      pkgs.fzf
      pkgs.htop
      pkgs.jq
      pkgs.m-cli
      pkgs.ripgrep
      pkgs.silver-searcher
      pkgs.skim
      pkgs.tree
      pkgs.urlview
      pkgs.yq

      # Build
      pkgs.autoconf
      pkgs.automake
      pkgs.cmake

      # Font
      pkgs.fontforge
      pkgs.tesseract

      # Fun
      pkgs.fortune
      pkgs.figlet

      # Codecs & file support
      pkgs.ffmpeg
      pkgs.gifsicle
      pkgs.imagemagick
      pkgs.lame
      pkgs.libpng
      pkgs.unrar

      # Databases
      pkgs.gdbm
      pkgs.postgresql
      pkgs.redis
      pkgs.sqlite

      # Git
      pkgs.git
      pkgs.git-crypt

      # Security
      (pkgs.pinentry.override { gtk2 = null; gcr = null; qt = null; })
      pkgs.gnupg
      pkgs.yubikey-manager

      # Languages
      pkgs.go
      pkgs.perl
      pkgs.rustc
      pkgs.scala

      # Development tools
      pkgs.cargo
      pkgs.ctags
      pkgs.emacs
      pkgs.html-tidy
      pkgs.httpie
      pkgs.maven
      pkgs.sbt
      pkgs.vagrant

      # Messaging
      pkgs.weechat

      # Editors
      pkgs.neovim
      pkgs.vim-vint

      pkgs.python27Packages.pynvim
      pkgs.python37Packages.pynvim

      pkgs.python37Packages.configparser
      pkgs.python37Packages.fonttools
      pkgs.python37Packages.websocket_client

      # Network utilities
      pkgs.dnsmasq
      pkgs.mosh
      pkgs.rclone

      # Shell
      pkgs.zsh
      pkgs.tmux
      pkgs.terminal-notifier

      # User Interface
      pkgs.skhd

      # Nix
      pkgs.nix
    ];

  nix.gc.automatic = true;

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [ overlays ];

  services.activate-system.enable = true;
  services.chunkwm.enable = false;
  services.nix-daemon.enable = true;
  services.nix-daemon.enableSocketListener = true;
  services.skhd.enable = false;

  networking.hostName = "Odrade";

  # Use local 'nixpkgs' and 'darwin-nix' instead of channel
  nix.nixPath =
    [
      "darwin=$HOME/.nix-defexpr/darwin"
      "nixpkgs=$HOME/.nix-defexpr/nixpkgs"
      "darwin-config=$HOME/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/$USER/channels"
    ];

  programs.zsh.enable = true;
}
