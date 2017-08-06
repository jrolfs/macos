{ config, lib, pkgs, ... }:

{
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
    [ pkgs.ack
      pkgs.autoconf
      pkgs.automake
      pkgs.cmake
      pkgs.dtach
      pkgs.fasd
      pkgs.fontforge
      pkgs.fortune
      pkgs.figlet
      pkgs.ffmpeg
      pkgs.fzf
      pkgs.gdbm
      pkgs.git
      pkgs.git-crypt
      pkgs.gnupg
      pkgs.go
      pkgs.irssi
      pkgs.jq
      pkgs.lame
      pkgs.luajit
      pkgs.mosh
      pkgs.neovim
      pkgs.perl
      pkgs.pinentry
      pkgs.python27Packages.neovim
      pkgs.python27Packages.powerline
      pkgs.python36Packages.neovim
      pkgs.python27Packages.pylint
      pkgs.python36Packages.pylint
      pkgs.reattach-to-user-namespace
      pkgs.silver-searcher
      pkgs.terminal-notifier
      pkgs.tmux
      pkgs.unrar
      pkgs.vagrant
      pkgs.vim-vint
      pkgs.zsh

      pkgs.nix
      pkgs.nix-repl ];

  programs.zsh.enable = true;

  services.activate-system.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Use darwin-nix instead of channel
  nix.nixPath =
    [
      "darwin=$HOME/.nix-defexpr/darwin"
      "darwin-config=$HOME/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/$USER/channels"
    ];
}
