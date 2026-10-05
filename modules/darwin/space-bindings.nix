{ config, lib, pkgs, ... }:

# Per-application Mission Control space assignments — the "Assign To" entry in a
# Dock tile's Options menu.
#
# macOS keeps these in `com.apple.spaces` under `app-bindings`, keyed by bundle
# identifier, and nix-darwin exposes nothing for it. They need declaring because
# they do not stay put. Modifying an application bundle makes the Dock drop that
# application's binding, and icons.nix rewrites the icon of every customised app
# — `Icon\r` plus the `com.apple.FinderInfo` xattr — whenever its agent fires,
# which is on any change under /Applications. kitty has a custom icon and is
# meant to be on every desktop, so it is the one that keeps reverting.
#
# This only heals the binding at switch time. The icon agent runs on its own
# schedule, so a binding dropped between switches stays dropped until the next
# one. The durable fix is for the icon setter to leave a bundle alone when it
# already carries the right icon; this is the backstop, not the cure.
#
# Only the two portable values belong here. A binding to one specific desktop is
# a space UUID out of SpacesDisplayConfiguration, particular to a machine's
# current set of spaces and replaced whenever a space is destroyed and recreated
# — per-host state rather than configuration. Those are left to the Dock's own
# menu, and preserved by the merge below.

let
  # Bundle identifier → "AllSpaces" (every desktop) or "" (none).
  bindings = {
    "net.kovidgoyal.kitty" = "AllSpaces";
  };

  user = lib.escapeShellArg config.system.primaryUser;

  # How `defaults read` renders each value, which is what the already-correct
  # check below matches on: a bare word for AllSpaces, an empty pair of quotes
  # for none.
  rendered = value: if value == "" then ''""'' else value;

  apply = pkgs.writeShellScript "set-space-bindings" # bash
    ''
      set -uo pipefail

      PATH=/usr/bin:/bin:/usr/sbin:/sbin

      # One read for the whole dict. Reading the domain rather than the file
      # keeps cfprefsd in the loop, which owns these preferences while the Dock
      # is running; reading the plist directly can be stale.
      current=$(defaults read com.apple.spaces app-bindings 2>/dev/null) || current=""

      changed=0

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (bundle: value: ''
          # Substring match on the line `defaults` would print, rather than
          # parsing the old-style plist it emits. The values here are a bare
          # word or an empty string, so there is nothing to disambiguate.
          case "$current" in
          *${lib.escapeShellArg ''"${bundle}" = ${rendered value};''}*) ;;
          *)
            # -dict-add merges one key. Writing the dict whole, as
            # system.defaults.CustomUserPreferences would, drops every binding
            # not declared here — including the per-desktop ones set by hand.
            defaults write com.apple.spaces app-bindings \
              -dict-add ${lib.escapeShellArg bundle} ${lib.escapeShellArg value} \
              && changed=1
            ;;
          esac
        '') bindings
      )}

      # The Dock reads these at launch and holds them in memory, so a write only
      # takes effect once it restarts. Restarting is visible, so it happens only
      # when something actually changed — which on most switches is nothing.
      if [[ $changed -eq 1 ]]; then
        killall Dock 2>/dev/null || true
      fi

      exit 0
    '';
in
{
  # postActivation runs as root, and these are per-user preferences belonging to
  # a GUI session, so it has to cross back into the user's session the same way
  # login-items.nix does.
  system.activationScripts.postActivation.text = lib.mkAfter # bash
    ''
      launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- ${apply}
    '';
}
