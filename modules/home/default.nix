{ pkgs, lib, hostname, userName, config, ... }:

{
  # Per-host customization is layered in as ./hosts/<hostname>.nix when
  # such a file exists. Lets host-specific tweaks live alongside shared
  # config without OS-conditional clutter.
  imports = lib.optional (builtins.pathExists ./hosts/${hostname}.nix) ./hosts/${hostname}.nix;

  home.username = userName;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${userName}" else "/home/${userName}";

  home.stateVersion = "24.05";

  # Pointer to the consolidated nix-config repo on disk. Read by the
  # cask-updater script in modules/darwin/tap.nix and other shell helpers.
  home.sessionVariables = {
    NIX_CONFIG_DIR = "${config.home.homeDirectory}/.config/system";
  };

  programs.home-manager.enable = true;
}
