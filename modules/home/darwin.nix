{ lib, pkgs, ... }:

# Darwin-only home-manager shared module. Loaded automatically for every
# darwinConfiguration via home-manager.sharedModules in flake.nix.

{
  # macOS-specific user-level home-manager configuration lives here.
  # Populated in phase 1 (task 7) — programs.zsh.initContent absorbs the
  # content of ~/.zshrc.darwin, etc.
}
