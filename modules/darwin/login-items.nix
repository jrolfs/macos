{ config, lib, pkgs, ... }:

# Login items are the right mechanism for GUI apps, and a LaunchAgent is not.
#
# An agent in launchd.user.agents exec's the Mach-O inside the bundle directly,
# which bypasses LaunchServices: the process never becomes a registered app
# instance, so TCC resolves its Accessibility and Automation grants against a
# different responsible-process chain and drops the prompts instead of showing
# them. That is why the Moom and Stay agents that used to live in daemons.nix
# were commented out. Moom could not read its own preferences and Stay could not
# run its scripts on a display-configuration change.
#
# There is a second failure mode worth knowing about. A plist in
# ~/Library/LaunchAgents is mirrored into the background task manager store as a
# `legacy agent` record, and that record's Disposition carries an `allowed` bit
# independent of `enabled`. A disallowed agent is never bootstrapped,
# `launchctl print` reports the label as not found, and nothing logs an error.
#
# System Events login items are the set of `app` records in that same store,
# which is byte-for-byte what an app's own "launch at login" checkbox writes.
# Driving it from here is indistinguishable from ticking the box by hand.
#
# Caveat for fresh hosts: the Automation -> System Events grant is attributed to
# whichever terminal launched the rebuild. A rebuild from a new terminal prompts
# once, and a genuinely non-interactive rebuild fails with -1743 and cannot
# prompt.
#
# This governs `app` records only. An app that registers a bundled helper
# instead gets a `login item` record, which System Events cannot enumerate, so
# the reconcile below neither manages nor removes it. 1Password, Karabiner, Arq
# and Fantastical are in that second category.
#
# Telling the two apart from outside the app is harder than it looks. Every
# candidate here links both `SMAppService` and `SMLoginItemSetEnabled`, and
# shipping a Contents/Library/LoginItems helper proves nothing either: CleanShot
# ships one and is still an `app` record, because sindresorhus's LaunchAtLogin
# package moved to SMAppService.mainApp on macOS 13+ and keeps the helper only
# for macOS 12. The authoritative answer is the record's `Type` in
# `sudo sfltool dumpbtm`.
#
# Declaring an app that turns out to use a helper is not harmful: macOS launches
# it from the `app` record regardless. The cost is a second, parallel
# registration path, and the app's own "start at login" UI still reading off.
# Tailscale is the open case, tracked below.

let
  apps = [
    "/Applications/CleanShot X.app"
    "/Applications/Moom.app"
    "/Applications/Raycast.app"
    "/Applications/Resilio Sync.app"
    "/Applications/Stay.app"

    # Only the menu bar UI. The tunnel is a system extension
    # (io.tailscale.ipn.macsys.network-extension) activated by systemextensionsd
    # and is already up before login, so this does not govern connectivity.
    #
    # Declared here rather than by flipping the app's own TailscaleStartOnLogin
    # default, which is 0, because it is unclear whether that key is read at
    # launch or written as a side effect of the app registering its helper.
    # Revisit if the record shows up as `login item` in a dump.
    "/Applications/Tailscale.app"
  ];

  user = lib.escapeShellArg config.system.primaryUser;

  # `hidden` is set on create but not compared, so flipping it on an item that
  # already exists needs the item removed first. Nothing here wants it.
  reconcile = pkgs.writeText "login-items.applescript" # applescript
    ''
      on run argv
        set desired to argv

        tell application "System Events"

          -- Deleting invalidates the element references held by an enclosing
          -- `repeat with ... in login items`, so this finds one offender, drops
          -- out to delete it, and rescans. The guard is only there because the
          -- loop's exit depends on the delete having taken effect.
          set guard to 0
          repeat
            set guard to guard + 1
            if guard > 100 then error "login items did not converge"

            set victim to missing value
            repeat with entry in login items
              -- An item whose app has been deleted returns `missing value`
              -- here, which coerces to the literal text "missing value". Either
              -- that or the empty string from a failed coercion falls through
              -- to the name match below, which is what removes stale items.
              set entryPath to ""
              try
                set entryPath to (path of entry) as text
              end try
              if entryPath is not in desired then
                set victim to (name of entry) as text
                exit repeat
              end if
            end repeat

            if victim is missing value then exit repeat

            delete (every login item whose name is victim)
            log "removed login item: " & victim
          end repeat

          set present to {}
          repeat with entry in login items
            try
              set end of present to (path of entry) as text
            end try
          end repeat

          repeat with wanted in desired
            set wantedPath to wanted as text
            if wantedPath is not in present then
              -- Keyed by bundle, so this is idempotent even if the scan above
              -- missed an equivalent item.
              make login item at end with properties {path:wantedPath, hidden:false}
              log "added login item: " & wantedPath
            end if
          end repeat

          -- System Events lists only the `app` records whose disposition is
          -- enabled, so an app that already holds a disabled record is invisible
          -- to the scan above and gets a `make` that may or may not flip it.
          -- CleanShot is in exactly that state. Re-read instead of assuming, so
          -- the case shows up as a warning rather than as an app that quietly
          -- never launches. Not fatal: a login item is not worth failing a
          -- rebuild over.
          set landed to {}
          repeat with entry in login items
            try
              set end of landed to (path of entry) as text
            end try
          end repeat

          repeat with wanted in desired
            set wantedPath to wanted as text
            if wantedPath is not in landed then
              log "WARNING: login item did not take: " & wantedPath
            end if
          end repeat

        end tell

        -- `make login item` evaluates to "login item UNKNOWN", and a run
        -- handler prints its result. Return nothing so activation output stays
        -- clean.
        return ""
      end run
    '';

  setLoginItems = pkgs.writeShellScript "set-login-items" # bash
    ''
      set -euo pipefail

      PATH=/usr/bin:/bin:/usr/sbin:/sbin

      declared=( ${lib.escapeShellArgs apps} )

      desired=()
      for app in "''${declared[@]}"; do
        if [[ -d "$app" ]]; then
          desired+=( "$app" )
        else
          echo "Skipping login item: $app not found"
        fi
      done

      # The reconcile removes every item it is not asked to keep, so handing it
      # an empty list would clear the lot. Reaching that state by way of a
      # Homebrew run that has not finished, or a host where every cask is
      # excluded, should not be how login items get wiped.
      if (( ''${#desired[@]} == 0 )); then
        echo "Skipping login items: none of the declared apps are installed"
        exit 0
      fi

      osascript ${reconcile} "''${desired[@]}" >/dev/null
    '';
in
{
  # After the mas and homebrew steps, so a first-time install of any of these is
  # already on disk by the time the existence check above runs.
  system.activationScripts.postActivation.text = lib.mkAfter # bash
    ''
      launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- ${setLoginItems}
    '';
}
