{ pkgs, ... }:

let
  overlays = import ./overlays.nix;

in
{
  imports = [

    ./daemons.nix
    ./defaults.nix
    ./fileicon.nix
    ./homebrew.nix
    ./icons.nix
    ./tap.nix

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

    # Theming
    pkgs.spicetify-cli

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

    pkgs.delta
    pkgs.gh
    pkgs.git
    pkgs.git-crypt
    pkgs.git-lfs
    pkgs.worktrunk

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

  programs.ssh.knownHosts = {
    "github.com/rsa" = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
    };
    "github.com/ecdsa" = {
      hostNames = [ "github.com" ];
      publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
    };
    "github.com/ed25519" = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = false;
    interactiveShellInit = ''

      HISTFILE=$HOME/.zhistory

    '';
  };
}
