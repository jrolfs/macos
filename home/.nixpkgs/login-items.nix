{ config, lib, pkgs, ... }:

let
  user = config.system.primaryUser;

  # Apps to open at login. This list is authoritative: any app login item
  # enabled on the machine but missing from here is removed on every rebuild.
  #
  # Only covers app login items, the kind created by an app's own "launch at
  # login" checkbox. Helper login items bundled inside an app
  # (Contents/Library/LoginItems, e.g. 1Password Launcher) are invisible to
  # System Events and can only be toggled by their parent app.
  loginItems = [
    "/Applications/CleanShot X.app"
    "/Applications/Hammerspoon.app"
    "/Applications/Moom.app"
    "/Applications/PixelSnap 2.app"
    "/Applications/Raycast.app"
    "/Applications/Resilio Sync.app"
    "/Applications/Stay.app"
    "/Applications/Velja.app"
    "/Users/${user}/Library/Application Support/Figma/FigmaAgent.app"
  ];

  # macOS keeps login items in a SIP-protected store that nothing can write
  # directly (/private/var/db/com.apple.backgroundtaskmanagement). Driving
  # System Events is the only supported way in, and it produces a record
  # identical to the one an app's own checkbox creates.
  listItems = pkgs.writeText "list-login-items.applescript" ''
    set AppleScript's text item delimiters to linefeed
    tell application "System Events" to set itemPaths to path of every login item
    return itemPaths as text
  '';

  addItem = pkgs.writeText "add-login-item.applescript" ''
    on run argv
      tell application "System Events"
        make login item at end with properties {path:(item 1 of argv), hidden:false}
      end tell
    end run
  '';

  removeItem = pkgs.writeText "remove-login-item.applescript" ''
    on run argv
      tell application "System Events"
        delete (every login item whose path is (item 1 of argv))
      end tell
    end run
  '';

  reconcile = pkgs.writeShellScript "reconcile-login-items" ''
    set -euo pipefail

    desired=(
      ${lib.concatMapStringsSep "\n      " lib.escapeShellArg loginItems}
    )

    if ! uid=$(id -u ${lib.escapeShellArg user} 2>/dev/null); then
      echo "login items: no such user ${user}, skipping" >&2
      exit 0
    fi

    # Activation runs as root. `launchctl asuser` crosses into the user's GUI
    # session so the items land in their list rather than root's, which is the
    # difference between reconciling and silently creating a parallel set of
    # login items for uid 0.
    run_as_user() {
      launchctl asuser "$uid" sudo -u ${lib.escapeShellArg user} /usr/bin/osascript "$@"
    }

    # Probe before mutating anything. Automation access is granted per terminal
    # and can't be declared in nix, so on a fresh machine this fails until it's
    # approved once. Bailing out whole keeps a half-applied reconcile (removals
    # landed, additions refused) off the table.
    if ! current_raw=$(run_as_user ${listItems} 2>/dev/null); then
      echo "login items: System Events unreachable, skipping reconcile." >&2
      echo "login items: grant Automation access to the terminal running this rebuild" >&2
      exit 0
    fi

    current=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && current+=("$line")
    done <<< "$current_raw"

    contains() {
      local needle=$1
      shift
      local item
      for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
      done
      return 1
    }

    for item in "''${current[@]}"; do
      if ! contains "$item" "''${desired[@]}"; then
        echo "login items: removing $item"
        run_as_user ${removeItem} "$item" \
          || echo "login items: failed to remove $item" >&2
      fi
    done

    for item in "''${desired[@]}"; do
      if contains "$item" "''${current[@]}"; then
        continue
      fi

      # System Events accepts a nonexistent path and silently does nothing, so
      # an uninstalled app and a typo look the same. Say which one happened.
      if [[ ! -d "$item" ]]; then
        echo "login items: $item not installed, skipping" >&2
        continue
      fi

      echo "login items: adding $item"
      run_as_user ${addItem} "$item" \
        || echo "login items: failed to add $item" >&2
    done
  '';
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${reconcile} || true
  '';
}
