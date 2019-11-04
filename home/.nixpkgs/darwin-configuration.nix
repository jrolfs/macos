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
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.springing.delay" = "0.0";
      "com.apple.springing.enabled" = true;
      "com.apple.swipescrolldirection" = true;
      "com.apple.trackpad.enableSecondaryClick" = true;
      "com.apple.trackpad.trackpadCornerClickBehavior" = 1;
      AppleFontSmoothing = 0;
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "WhenScrolling";
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = true;
      NSDisableAutomaticTermination = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSScrollAnimationEnabled = true;
      NSTableViewDefaultSizeMode = 2;
      NSTextShowsControlCharacters = false;
      NSUseAnimatedFocusRing = true;
      NSWindowResizeTime = "0.01";
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
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
      pkgs.rename
      pkgs.ripgrep
      pkgs.sd
      pkgs.silver-searcher
      pkgs.skim
      pkgs.thefuck
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
      (pkgs.pinentry.override { enabledFlavors = [ "curses" "tty" ]; })
      pkgs.gnupg
      pkgs.keybase
      pkgs.yubikey-manager

      # Languages
      pkgs.go
      pkgs.rustc
      pkgs.scala

      # Development tools
      pkgs.cargo
      pkgs.ctags
      pkgs.emacs
      pkgs.html-tidy
      pkgs.httpie
      # pkgs.http-prompt
      pkgs.maven
      pkgs.sbt
      pkgs.vagrant
      pkgs.watchman

      # Messaging
      pkgs.weechat
      pkgs.weechatScripts.wee-slack

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
      pkgs.mitmproxy
      pkgs.mosh
      pkgs.ngrok
      pkgs.rclone

      # Shell
      pkgs.zsh
      pkgs.tmux
      pkgs.tmuxp
      pkgs.terminal-notifier

      # Nix
      pkgs.nix
    ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  nixpkgs.overlays = [ overlays ];

  services.activate-system.enable = true;
  services.chunkwm.enable = false;
  services.nix-daemon.enable = false;
  services.postgresql = {
    enable = false;
    enableTCPIP = true;
  };
  services.skhd.enable = false;

  nix.nixPath =
    [
      {
        darwin = "$HOME/.nix-defexpr/darwin";
        nixpkgs = "$HOME/.nix-defexpr/nixpkgs";
        darwin-config = "$HOME/.nixpkgs/darwin-configuration.nix";
      }
    ];

  programs.zsh.enable = true;
}
