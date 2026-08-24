{ pkgs, lib, config, ... }:

# The desktop picture.
#
# The image files sync themselves: ~/Images is a Resilio share, and
# ~/Images/Wallpapers is the library inside it. What was never synced is the
# *choice* — a machine with the entire library still had to be told which
# picture to use, by hand, in System Settings. That is what this declares.
#
# It has to be done through NSWorkspace (which is all desktoppr is) rather than
# by writing the preference. macOS keeps the answer in
# ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist, and
# WallpaperAgent owns that file rather than reading it: writing the new picture
# in by hand changes nothing on screen, and the agent overwrites the file from
# its own state the next time Dock restarts. Measured on macOS 26.

let
  wallpaper = "${config.home.homeDirectory}/Images/Wallpapers/BLACK/BLACK II - Gruvbox Material.png";

  # Hammerspoon's CLI, which is what makes the per-space loop below possible.
  # It lives inside the cask rather than in $(brew --prefix)/bin, which is only
  # a symlink Hammerspoon offers to create.
  hs = "/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs";

  spaceIds = ''local ids = {} for _, list in pairs(hs.spaces.allSpaces()) do for _, id in ipairs(list) do if hs.spaces.spaceType(id) == "user" then ids[#ids+1] = id end end end return "spaces:" .. table.concat(ids, " ")'';

  apply = pkgs.writeShellScript "wallpaper-apply" ''
    set -uo pipefail

    export PATH=${lib.makeBinPath [ pkgs.desktoppr pkgs.coreutils pkgs.gnugrep ]}:$PATH

    image=${lib.escapeShellArg wallpaper}

    # A machine outside the share, or one where Resilio hasn't caught up yet.
    # Pointing the desktop at a file that isn't there paints it black.
    if [ ! -f "$image" ]; then
      echo "wallpaper: $image has not synced yet, leaving the desktop alone" >&2
      exit 0
    fi

    current=$(desktoppr) || current=

    # Both the idempotence guard and the reason for everything below it:
    # NSWorkspace reads and writes the *active* space only.
    [ "$current" = "$image" ] && exit 0

    desktoppr all "$image"

    # Every other space is still on the old picture. System Settings writes an
    # "all spaces and displays" scope that no public API reaches, so the only
    # way to the rest of them is to go there. Hammerspoon drives that through
    # Mission Control, so it needs Accessibility — if the hop fails, that space
    # keeps its old picture and the rest still get done.
    #
    # This runs only when the declared picture actually changed, which is the
    # one moment a switch is allowed to move the screen around. A display that
    # isn't plugged in at that moment is out of reach the same way and keeps its
    # old picture until the next change lands while it is attached.
    if [ ! -x ${hs} ]; then
      echo "wallpaper: no Hammerspoon CLI, so only the active space changed" >&2
      exit 0
    fi

    # Sentinel-prefixed because `hs -c` interleaves its own "-- Loading
    # extension: spaces" line on the first call after Hammerspoon starts.
    spaces=$(${hs} -c ${lib.escapeShellArg spaceIds} 2>/dev/null | grep '^spaces:' | head -1)
    spaces=''${spaces#spaces:}

    origin=$(${hs} -c 'return "focused:" .. tostring(hs.spaces.focusedSpace())' 2>/dev/null | grep '^focused:' | head -1)
    origin=''${origin#focused:}

    for space in $spaces; do
      [ "$space" = "$origin" ] && continue

      ${hs} -c "hs.spaces.gotoSpace($space)" >/dev/null 2>&1 || continue
      sleep 2

      desktoppr all "$image"
    done

    if [ -n "$origin" ]; then
      ${hs} -c "hs.spaces.gotoSpace($origin)" >/dev/null 2>&1 || true
    fi

    exit 0
  '';
in
{
  home.packages = [ pkgs.desktoppr ];

  home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${apply} \
      || warnEcho "wallpaper: could not set the desktop picture — run desktoppr by hand to see why"
  '';
}
