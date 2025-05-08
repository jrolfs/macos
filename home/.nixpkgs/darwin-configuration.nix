{ pkgs, ... }:

let
  overlays = import ./overlays.nix;
  # Support Nix installs using the old nixbld group number
  nixbldGid = builtins.trace "Querying nixbld group..."
    (pkgs.lib.toInt (builtins.readFile (
      pkgs.runCommand "nixbld-gid" {} ''
        /usr/bin/dscl . -read /Groups/nixbld PrimaryGroupID |
        awk '{print $2}' > $out
      ''
    )));
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
      pkgs.mackup
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

      pkgs.pinentry-curses
      pkgs.pinentry_mac
      pkgs.gnupg
      pkgs.keybase
      pkgs.yubikey-manager

      #
      # Development tools

      pkgs.httpie
      pkgs.watchman

      #
      # Infrastructure

      pkgs.coder
      pkgs.kubectl
      pkgs.kubectx
      (pkgs.google-cloud-sdk.withExtraComponents [
        pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
      ])

      # SDKs

      # Currently disabled as using the cask for compatibility
      # with the auth plugin and general compatibility with work
      # pkgs.google-cloud-sdk

      #
      # Editors

      pkgs.neovide
      pkgs.neovim
      pkgs.nil
      pkgs.tree-sitter

      pkgs.python311Packages.pynvim
      pkgs.python311Packages.grip

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


  system.defaults.LaunchServices.LSQuarantine = false;
  system.activationScripts.applications.enable = true;

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
