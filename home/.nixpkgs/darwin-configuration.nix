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
      pkgs.urlview
      pkgs.yq

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
      pkgs.gifsicle
      pkgs.imagemagick
      pkgs.lame
      pkgs.libpng
      pkgs.unrar

      # Databases
      pkgs.gdbm
      pkgs.postgresql
      pkgs.redis

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
      pkgs.emacs
      pkgs.html-tidy
      pkgs.httpie
      pkgs.vagrant

      # Messaging
      pkgs.weechat

      # Editors
      pkgs.neovim
      pkgs.vim-vint

      pkgs.python27Packages.neovim
      pkgs.python36Packages.configparser
      pkgs.python36Packages.fonttools
      pkgs.python36Packages.neovim
      pkgs.python36Packages.pylint
      pkgs.python36Packages.websocket_client

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
      pkgs.chunkwm.core
      pkgs.chunkwm.tiling
      pkgs.chunkwm.border

      # Nix
      pkgs.nix
    ];

  nix.gc.automatic = true;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ overlays ];

  services.activate-system.enable = true;
  services.nix-daemon.enable = true;
  services.chunkwm.enable = false;
  services.skhd.enable = false;

  services.chunkwm.package = pkgs.chunkwm.core;
  services.chunkwm.plugins.list = [ "border" "tiling" ];
  services.chunkwm.plugins.dir = "/run/current-system/sw/bin/chunkwm-plugins/";

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
