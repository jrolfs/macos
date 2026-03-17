{ pkgs, ... }:

let
  overlays = import ./overlays.nix;
  # Support Nix installs using the old nixbld group number
  nixbldGid = builtins.trace "Querying nixbld group..." (
    pkgs.lib.toInt (
      builtins.readFile (
        pkgs.runCommand "nixbld-gid" { } ''
          /usr/bin/dscl . -read /Groups/nixbld PrimaryGroupID |
          awk '{print $2}' > $out
        ''
      )
    )
  );
in
{
  imports = [

    ./daemons.nix
    ./defaults.nix
    ./fileicon.nix
    ./homebrew.nix
    ./icons.nix

    # ./applications/codium.nix
  ];

  # Packages

  environment.systemPackages = [

    #
    # Utilities

    # Shell

    pkgs.atuin
    pkgs.bat
    pkgs.bottom
    pkgs.direnv
    pkgs.dtach
    pkgs.eza
    pkgs.fasd
    pkgs.fd
    pkgs.fish
    pkgs.jq
    pkgs.ripgrep
    pkgs.sd
    pkgs.skim
    pkgs.starship
    pkgs.tealdeer
    pkgs.terminal-notifier
    pkgs.tmux
    pkgs.yq
    pkgs.zsh

    # Network

    pkgs.ngrok
    pkgs.rclone
    pkgs.wakeonlan

    #
    # macOS

    pkgs.m-cli
    pkgs.mackup
    pkgs.nightlight
    pkgs.sketchybar

    #
    # Build

    pkgs.autoconf
    pkgs.automake
    pkgs.cmake

    #
    # Fun

    pkgs.fortune
    pkgs.figlet
    pkgs.dotacat

    #
    # Media

    pkgs.ffmpeg
    pkgs.imagemagick
    pkgs.yt-dlp

    #
    # Git

    pkgs.git
    pkgs.git-crypt
    pkgs.git-lfs
    pkgs.delta
    pkgs.gh

    #
    # Security

    pkgs.pinentry-curses
    pkgs.pinentry_mac
    pkgs.gnupg
    pkgs.keybase
    pkgs.yubikey-manager

    #
    # Development tools

    pkgs.httpie
    pkgs.mise
    pkgs.watchman

    #
    # Infrastructure

    pkgs.kubectl
    pkgs.kubectx

    #
    # Editors

    pkgs.neovide
    pkgs.neovim
    pkgs.nil
    pkgs.tree-sitter

    #
    # Shell

    # Nix
    pkgs.devbox
    pkgs.nixpkgs-fmt

    # AI
    pkgs.claude-code
    pkgs.claude-monitor
    pkgs.claude-code-router

  ];

  system.activationScripts.applications.enable = true;
  system.primaryUser = "jamie";

  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  nixpkgs.overlays = [ overlays ];

  system.stateVersion = 5;
  ids.gids.nixbld = nixbldGid;

  services.postgresql = {
    enable = false;
    enableTCPIP = true;
  };
  services.skhd.enable = false;

  security.pam.services.sudo_local.touchIdAuth = true;

  # NOTE: disabling nix-darwin's support for configuring Nix itself
  # as it conflicts with Determinate Nix. I'm leaving this stuff
  # here in case I switch to something else and for reference.
  nix.enable = false;

  nix.extraOptions = "experimental-features = nix-command flakes";
  nix.nixPath = [
    {
      darwin = "/Users/jamie/.nix-defexpr/darwin";
      nixpkgs = "/Users/jamie/.nix-defexpr/nixpkgs";
      darwin-config = "/Users/jamie/.nixpkgs/darwin-configuration.nix";
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
