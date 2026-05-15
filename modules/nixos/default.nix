{ pkgs, lib, inputs, ... }:

# Shared NixOS configuration. Imported by every nixosConfiguration via
# flake.nix's mkNixos. Host-specific bits live in hosts/<hostname>/.

{
  system.stateVersion = "24.05";

  # Nix daemon settings — keep parity with the darwin module so
  # `nix shell nixpkgs#foo` and `nix-shell -p foo` resolve the same way
  # across mac and linux hosts.
  nix.package = pkgs.lix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;

  # Default user shell across NixOS hosts. Matches the darwin side so
  # the lifted-and-shifted .zshrc / .zshenv work without a chsh dance.
  programs.zsh.enable = true;

  # Time + locale defaults. Override per host if needed.
  time.timeZone = lib.mkDefault "America/Los_Angeles";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Console / terminal defaults — Linux equivalents of the macOS keyboard
  # behavior tweaks. Override in host file if it has a different layout.
  console.keyMap = lib.mkDefault "us";

  # NFS client support for the QNAP media mount declared at the host level.
  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  # Tools that should always be on PATH on any NixOS host. Mirrors the
  # baseline that's in modules/darwin/default.nix's environment.systemPackages
  # but lighter — only the cross-platform essentials. Host-specific apps
  # land in services modules.
  environment.systemPackages = with pkgs; [
    bat
    bottom
    coreutils
    curl
    direnv
    eza
    fd
    git
    git-crypt
    htop
    jq
    mise
    neovim
    nil
    nixpkgs-fmt
    ripgrep
    starship
    tmux
    wget
    yq
  ];
}
