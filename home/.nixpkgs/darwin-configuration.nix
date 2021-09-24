{ config, lib, pkgs, ... }:

let
  overlays = import ./overlays.nix;
in
{
  imports = [
    ./defaults.nix
    ./homebrew.nix
  ];

  # Packages

  environment.systemPackages =
    [

      # Terminal utilities
      pkgs.bat
      pkgs.bottom
      pkgs.dtach
      pkgs.exa
      pkgs.fasd
      pkgs.fd
      pkgs.jq
      pkgs.m-cli
      pkgs.mcfly
      pkgs.ripgrep
      pkgs.sd
      pkgs.skim
      pkgs.starship
      pkgs.tealdeer
      pkgs.yq

      # Build
      pkgs.autoconf
      pkgs.automake
      pkgs.cmake

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

      # Git
      pkgs.git
      pkgs.git-crypt
      pkgs.git-lfs
      pkgs.gitAndTools.delta
      pkgs.gitAndTools.diff-so-fancy
      pkgs.gitAndTools.gh
      pkgs.gitAndTools.hub

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
      pkgs.html-tidy
      pkgs.httpie
      pkgs.maven
      pkgs.watchman

      # SDKs
      pkgs.google-cloud-sdk

      # Editors
      pkgs.neovim
      pkgs.vim-vint

      pkgs.python39Packages.pynvim
      pkgs.python39Packages.grip

      # Network utilities
      #pkgs.mosh
      pkgs.ngrok
      pkgs.rclone

      # Shell
      pkgs.direnv
      pkgs.terminal-notifier
      pkgs.tmux
      pkgs.zsh

      # Nix
      pkgs.nixUnstable
      pkgs.nixpkgs-fmt
    ];

  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  nixpkgs.overlays = [ overlays ];

  services.activate-system.enable = true;
  services.nix-daemon.enable = true;
  services.postgresql = {
    enable = false;
    enableTCPIP = true;
  };
  services.skhd.enable = false;

  users.nix.configureBuildUsers = true;

	nix.package = pkgs.nixFlakes;
	nix.extraOptions = lib.optionalString (config.nix.package == pkgs.nixFlakes)
		"experimental-features = nix-command flakes";

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
