{ pkgs, ... }:

# Shared NixOS configuration. Phase 2 placeholder — fleshed out when the
# NUC host comes online.

{
  system.stateVersion = "24.05";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
