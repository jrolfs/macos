{ config, lib, pkgs, ... }:

let
  overlays = self: super: rec {
    chunkwm = super.recurseIntoAttrs (super.callPackage (super.fetchFromGitHub {
      owner = "kubek2k";
      repo = "chunkwm.nix";
      sha256 = "11fwr29q18x4349wdg1pd7wqd1wvxsib6mjz7c93slf40h88vd53";
      rev = "0.1";
    }) {
      inherit (super.darwin.apple_sdk.frameworks) Carbon Cocoa ApplicationServices;
    });
  };
in
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
      pkgs.python36Packages.neovim
      pkgs.python36Packages.pylint
      pkgs.python36Packages.websocket_client

      # Network utilities
      pkgs.mosh
      pkgs.rclone

      # Shell
      pkgs.zsh
      pkgs.tmux
      pkgs.terminal-notifier

      # User Interface
      pkgs.skhd
      pkgs.chunkwm.core
      pkgs.chunkwm.ffm
      pkgs.chunkwm.tiling

      # Nix
      pkgs.nix
    ];

  nix.gc.automatic = true;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ overlays ];

  services.activate-system.enable = true;
  services.nix-daemon.enable = true;

  services.chunkwm.enable = true;
  services.chunkwm.package = pkgs.chunkwm.core;
  services.chunkwm.plugins.list = [ "ffm" "tiling" ];
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

  environment.etc."zshrc".text =
    let cfg = config.programs.zsh; in pkgs.lib.mkForce
      ''
        # /etc/static/zshrc

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
