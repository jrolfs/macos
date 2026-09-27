{ lib, pkgs, ... }:

# Per-display-configuration settings, applied as one script that Stay calls.
#
# Stay's own actions used to hold the logic: four shell/AppleScript bodies per
# workspace, thirty-three in total, with the values scattered across a Core Data
# store that nothing here could see. This keeps Stay as the trigger, because its
# display-configuration matching already works, and moves everything it does
# into one generated script.
#
# The Electron apps are the reason this exists. Superhuman and Slack have no
# settable zoom: Slack persists `.settings.zoomLevel` in
# storage/root-state.json but only reads it at startup, and Superhuman does not
# persist zoom at all (its `partition.per_host_zoom_levels` stays empty), so
# something has to drive the UI. The old actions did that with System Events
# keystrokes, which meant activating each app in turn and stealing focus.
#
# Hammerspoon's selectMenuItem presses the menu item through the accessibility
# API instead, which works on an application that is not frontmost and never
# raises it. Verified against Slack with kitty focused throughout. It also drops
# Stay's TCC dependency entirely: Stay now runs a plain shell script, and the
# Accessibility grant that matters belongs to Hammerspoon, which already has it.
#
# Zoom is set absolutely, Actual Size then N steps, never relatively. Chromium
# coalesces rapid zoom changes and writes the result back on a lag, so a
# relative step applied to an unknown starting point drifts. The old AppleScript
# opened with Cmd+0 for the same reason.

let
  # kitty is a font size in points. moomGap is Moom's grid gap in pixels.
  # superhuman and slack are Chromium zoom levels, where 0 is 100% and each
  # step is one notch, so -2 means two presses of Zoom Out.
  #
  # Values carried over verbatim from the Stay actions they replace. The ones
  # marked `inferred` had no action at all, or in the case of 13" M4 Air's Slack
  # entry an action with an empty script, and follow the pattern of the rest:
  # -1/-3 on the low-DPI externals, 0/-2 on Retina.
  profiles = {
    "900p" = { kitty = 12; moomGap = 20; superhuman = -1; slack = -3; }; # slack inferred
    "1080p" = { kitty = 12; moomGap = 20; superhuman = -1; slack = -3; };
    "1440p" = { kitty = 14; moomGap = 23; superhuman = 0; slack = -2; }; # superhuman inferred
    "13\" M1 Air" = { kitty = 13; moomGap = 12; superhuman = -1; slack = -2; }; # slack inferred
    "13\" M1 Air ← iPad × Folio" = { kitty = 13; moomGap = 12; superhuman = 0; slack = -2; }; # slack inferred
    "13\" M4 Air" = { kitty = 13; moomGap = 15; superhuman = 0; slack = -2; }; # slack inferred
    "13\" M4 Air ← iPad × Stand" = { kitty = 13; moomGap = 15; superhuman = 0; slack = -2; };
    "14\" Pro" = { kitty = 13; moomGap = 15; superhuman = 0; slack = -2; }; # slack inferred
    "1440 × 810, 1180 × 820" = { kitty = 13; moomGap = 12; superhuman = 0; slack = -2; }; # both inferred

    # Workspaces that had no actions at all. Values follow the machine they
    # describe: the 14" Pro pair tracks 14" Pro, the M4 Air pair tracks M4 Air,
    # and 1180 × 820, 1470 × 956 is the 14" Pro with the iPad alongside.
    "14\" Pro ← iPad → Folio" = { kitty = 13; moomGap = 15; superhuman = 0; slack = -2; };
    "13\" M4 Air + iPad × Folio" = { kitty = 13; moomGap = 15; superhuman = 0; slack = -2; };
    "1180 × 820, 1470 × 956" = { kitty = 13; moomGap = 15; superhuman = 0; slack = -2; };
  };

  arm = name: p: ''
    ${lib.escapeShellArg name})
      kitty_size=${toString p.kitty}
      moom_gap=${toString p.moomGap}
      superhuman_zoom=${toString p.superhuman}
      slack_zoom=${toString p.slack}
      ;;'';

  displayProfile = pkgs.writeShellScriptBin "display-profile" # bash
    ''
      set -uo pipefail

      PATH=/usr/bin:/bin:/usr/sbin:/sbin

      # Not in nixpkgs on this host: kitty is a cask, and hs ships inside the
      # Hammerspoon bundle that daemons.nix keeps alive.
      kitty=/opt/homebrew/bin/kitty
      hs=/opt/homebrew/bin/hs

      if [[ $# -ne 1 ]]; then
        echo "usage: display-profile <profile>" >&2
        exit 64
      fi

      case "$1" in
      ${arms}
        *)
          echo "display-profile: no profile named '$1'" >&2
          exit 1
          ;;
      esac

      # Every step below is best effort. Stay fires this on a display change,
      # which is exactly when an app may be mid-relaunch or not running at all,
      # and a partial apply beats aborting the rest of the profile.

      if [[ -x "$kitty" ]]; then
        # kitty leaves a socket behind per instance and never reaps them, so the
        # newest is the live one. Drop the rest first or the pick is a coin flip.
        sockets=(~/.local/share/kitty/socket*)
        if [[ -e "''${sockets[0]}" ]]; then
          ls -t ~/.local/share/kitty/socket* 2>/dev/null | tail -n +2 | while read -r stale; do
            rm -f -- "$stale"
          done
          socket=$(ls -t ~/.local/share/kitty/socket* 2>/dev/null | head -1)
          [[ -n "$socket" ]] && "$kitty" @ --to "unix:$socket" set-font-size "$kitty_size" >/dev/null 2>&1
        fi
      fi

      # Moom re-reads this per grid operation, so no restart or nudge is needed.
      defaults write com.manytricks.Moom "Grid Spacing: Gap" -int "$moom_gap" 2>/dev/null

      set_zoom() {
        local app="$1" level="$2" direction="Zoom Out" steps

        steps=''${level#-}
        [[ "$level" -gt 0 ]] && direction="Zoom In"

        [[ -x "$hs" ]] || return 0

        # Delay between presses because Chromium debounces zoom changes; without
        # it a run of steps collapses into fewer than were asked for.
        "$hs" -c "
          local app = hs.application.get('$app')
          if not app then return 'absent' end
          app:selectMenuItem({'View', 'Actual Size'})
          for _ = 1, $steps do
            hs.timer.usleep(120000)
            app:selectMenuItem({'View', '$direction'})
          end
          return 'ok'
        " >/dev/null 2>&1 || true
      }

      set_zoom Superhuman "$superhuman_zoom"
      set_zoom Slack "$slack_zoom"

      exit 0
    '';

  arms = lib.concatStringsSep "\n" (lib.mapAttrsToList arm profiles);
in
{
  environment.systemPackages = [ displayProfile ];
}
