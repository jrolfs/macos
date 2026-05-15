{ lib, pkgs, config, userName, ... }:

# Linux-only home-manager shared module. Loaded automatically for every
# nixosConfiguration via home-manager.sharedModules in flake.nix.
#
# Counterpart to modules/home/darwin.nix. Provides Linux-specific
# environment tweaks; the bulk of the shell config is shared via
# modules/home/default.nix and works on both OSes.

{
  # ~/.zshrc.linux is sourced by ~/.zshrc when uname is Linux.
  # Mirrors the .zshrc.darwin pattern from darwin.nix; the existing
  # dotfiles/home/.zshrc has the platform-rc lookup that picks the
  # right file based on uname.
  home.file.".zshrc.linux".text = ''
    #
    #
    # Aliases ----------------------------------------------------------------------

    alias nix-switch="sudo -E nixos-rebuild switch --flake $NIX_CONFIG_DIR#$(hostname -s) --show-trace"
    alias nix-rebuild="sudo -E nixos-rebuild build --flake $NIX_CONFIG_DIR#$(hostname -s) --show-trace"
    alias nix-search="nix search nixpkgs"
  '';

  # GPG agent on Linux uses pinentry-curses (or pinentry-gnome3 if
  # there's a desktop). Irulan is a headless server, so curses is fine.
  # The ~/.gnupg/gpg-agent.conf rsync'd from the dotfiles tree currently
  # sets pinentry-program for macOS (pinentry-mac); on Linux that path
  # doesn't exist. Home-manager doesn't override the rsync'd file, so
  # we declare it inline here to take precedence.
  home.file.".gnupg/gpg-agent.conf" = lib.mkForce {
    text = ''
      pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
      default-cache-ttl 60480000
      max-cache-ttl 60480000
    '';
  };

  # Linux-side packages on top of the system-wide environment.systemPackages
  # in modules/nixos/default.nix. User-installed via home-manager profile.
  home.packages = with pkgs; [
    # Currently empty — add as Linux-only personal tools surface.
  ];
}
