{ pkgs, ... }:

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

      #
      # Utilities

      pkgs.atuin
      pkgs.bat
      pkgs.bottom
      pkgs.dtach
      pkgs.eza
      pkgs.fasd
      pkgs.fd
      pkgs.jq
      pkgs.m-cli
      pkgs.mcfly
      pkgs.rename
      pkgs.ripgrep
      pkgs.sd
      pkgs.skim
      pkgs.starship
      pkgs.tealdeer
      pkgs.yabai
      pkgs.yq

      #
      # Build

      pkgs.autoconf
      pkgs.automake
      pkgs.cmake

      #
      # Fun

      pkgs.fortune
      pkgs.figlet

      #
      # Codecs & file support

      pkgs.ffmpeg
      pkgs.gifsicle
      pkgs.imagemagick
      pkgs.lame
      pkgs.libpng
      pkgs.unrar

      #
      # Git

      pkgs.git
      pkgs.git-crypt
      pkgs.git-lfs
      pkgs.gitAndTools.delta
      pkgs.gitAndTools.diff-so-fancy
      pkgs.gitAndTools.gh
      pkgs.gitAndTools.hub

      #
      # Security

      (pkgs.pinentry.override { enabledFlavors = [ "curses" "tty" ]; })
      pkgs.gnupg
      pkgs.keybase
      pkgs.yubikey-manager

      #
      # Development tools

      pkgs.httpie
      pkgs.watchman

      # SDKs

      # Currently disabled as using the cask for compatibility
      # with the auth plugin and general compatibility with work
      # pkgs.google-cloud-sdk

      #
      # Editors

      pkgs.neovim
      pkgs.tree-sitter
      pkgs.neovide

      pkgs.python310Packages.pynvim
      pkgs.python310Packages.grip

      #
      # Network utilities

      pkgs.ngrok
      pkgs.rclone
      pkgs.wakeonlan

      #
      # Shell

      pkgs.direnv
      pkgs.fish
      pkgs.terminal-notifier
      pkgs.tmux
      pkgs.zsh

      # Nix
      pkgs.devbox
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

  security.pam.enableSudoTouchIdAuth = true;

  #  launchd.agents.apply-icons = {
  #    # FIXME: `$XDG_DATA_HOME` isn't interpolating here, need to figure
  #    # out how to reference `$XDG_DATA_HOME` or at least `$HOME` from Nix
  #    command = "$XDG_DATA_HOME/icons/apply.sh";
  #
  #	  serviceConfig.StandardErrorPath = "$XDG_DATA_HOME/icons/launchd/stderr.log";
  #	  serviceConfig.StandardOutPath = "$XDG_DATA_HOME/icons/launchd/stdout.log";
  #    serviceConfig.WatchPaths = ["/Applications" "$XDG_DATA_HOME/icons"];
  #    serviceConfig.WorkingDirectory = "$XDG_DATA_HOME/icons";
  #
  #    serviceConfig.KeepAlive = false;
  #    serviceConfig.ProcessType = "Background";
  #    serviceConfig.ThrottleInterval = 300;
  #  };

  nix.configureBuildUsers = true;
	nix.extraOptions = "experimental-features = nix-command flakes";

  nix.nixPath =
    [
      {
        darwin = "$HOME/.nix-defexpr/darwin";
        nixpkgs = "$HOME/.nix-defexpr/nixpkgs";
        darwin-config = "$HOME/.nixpkgs/darwin-configuration.nix";
      }
    ];

  programs.zsh = {
    enable = true;
    enableCompletion = false;
    interactiveShellInit = ''

      HISTFILE=$HOME/.zhistory

    '';
  };
}
