{ pkgs, inputs, ... }:

# Puts the `secrets` CLI on PATH so managing 1Password-backed secrets doesn't
# need a `nix run` prefix or a bootstrap checkout. Shared by darwin and NixOS:
# Irulan needs it as much as the Macs do.
#
# Working *on* the CLI is a different thing — `nix develop` in the bootstrap
# repo shadows this with a version that runs the working tree.

{
  environment.systemPackages = [
    inputs.bootstrap.packages.${pkgs.stdenv.hostPlatform.system}.secrets
  ];
}
