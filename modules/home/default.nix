{ pkgs, lib, hostname, userName, config, ... }:

{
  # Per-host customization is layered in as ./hosts/<hostname>.nix when
  # such a file exists. Lets host-specific tweaks live alongside shared
  # config without OS-conditional clutter.
  imports = lib.optional (builtins.pathExists ./hosts/${hostname}.nix) ./hosts/${hostname}.nix;

  home.username = userName;
  # home.homeDirectory is auto-derived from users.users.<name>.home by
  # the nix-darwin / nixos home-manager integration. We just need to
  # ensure users.users.${userName}.home is set in the system module.
  home.stateVersion = "24.05";

  # Pointer to the consolidated nix-config repo on disk. Read by the
  # cask-updater script in modules/darwin/tap.nix and other shell helpers.
  home.sessionVariables = {
    NIX_CONFIG_DIR = "${config.home.homeDirectory}/.config/system";
  };

  programs.home-manager.enable = true;
}
