{ config, pkgs, ... }:

# Accessibility Zoom, which nothing else here can declare.
#
# com.apple.universalaccess is gated on Full Disk Access: cfprefsd refuses the
# write from a process without the grant. nix-darwin's activation writes user
# defaults through `launchctl asuser ... sudo --user=...`, which holds no grant,
# so the write fails with "Could not write domain", and because activation runs
# under `set -e` that one failure aborted every remaining step behind it. That
# is why defaults.nix leaves system.defaults.universalaccess alone and this goes
# through fda.nix's shim instead, which does hold the grant.
#
# Two keys carry the feature. The scroll-gesture toggle is what turns zoom on at
# all, and smooth images off keeps the magnified picture pixel-crisp rather than
# interpolated. The modifier is mirrored outside the protected domain, as
# HIDScrollZoomModifierMask in both trackpad domains, so defaults.nix could set
# that half without any of this, but on its own it only chooses which modifier
# and enables nothing. It is set here to keep the whole gesture in one place.

let
  domain = "com.apple.universalaccess";

  apply = pkgs.writeShellScriptBin "accessibility-defaults" # bash
    ''
      set -eu

      # 786432 is ⌃⌥ as NSEvent modifier flags: control (1 << 18) together with
      # option (1 << 19).
      defaults write ${domain} closeViewScrollWheelToggle -bool true
      defaults write ${domain} closeViewScrollWheelModifiersInt -int 786432
      defaults write ${domain} closeViewSmoothImages -bool false

      # universalaccessd reads these once and caches them, so a write it is not
      # told about does nothing until the next login.
      killall universalaccessd 2>/dev/null || true
    '';
in
{
  fda.operations.accessibility-defaults = apply;

  # RunAtLoad with no watch: these are login-time settings, and nix-darwin
  # reloads the agent on a switch that changes it, so both paths are covered.
  launchd.user.agents.accessibility-defaults = {
    serviceConfig = {
      ProgramArguments = [ config.fda.runPath "accessibility-defaults" ];
      RunAtLoad = true;
    };
  };
}
