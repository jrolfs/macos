{ config, lib, pkgs, ... }:

# Apps that start at login without being System Events login items, so
# login-items.nix cannot reach them. Spotify and Fantastical start from helpers
# they register themselves, and each is driven through the setting its owner
# reads instead.
#
# Session restore is deliberately not handled here. Locking loginwindow's
# relaunch list (TALAppsToRelaunchAtLogin in the ByHost plist) did not stop apps
# reopening on macOS 26, so quitting everything before a restart is left to the
# Raycast command in dotfiles/home/.local/share/raycast/scripts.

let
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;

  # Spotify starts itself at login from Contents/Library/LoginItems, and
  # registers or unregisters that helper according to app.autostart-mode in
  # its prefs file. That file is plain key=value text which Spotify writes in
  # full on quit, so an edit made while it runs is overwritten. It is stopped
  # first and started again afterwards, which also gets the new mode applied to
  # the helper straight away rather than at Spotify's next launch.
  #
  # The mode's other values are "minimized" and "normal". An unset mode is not
  # off: Spotify treats it as minimized.
  spotifyAutostart = pkgs.writeShellScript "spotify-autostart" # bash
    ''
      set -euo pipefail

      PATH=/usr/bin:/bin:/usr/sbin:/sbin

      prefs="${home}/Library/Application Support/Spotify/prefs"
      setting='app.autostart-mode="off"'

      # Spotify writes the file on first run, along with its own default mode.
      if [[ ! -f "$prefs" ]]; then
        echo "Skipping Spotify autostart: it has not been run yet"
        exit 0
      fi

      grep -qxF "$setting" "$prefs" && exit 0

      echo "Turning off Spotify's launch at login..."

      running=false
      if pgrep -xq Spotify; then
        running=true

        # SIGTERM rather than a quit Apple event, which would need an
        # Automation grant for Spotify. Chromium shuts down cleanly on it.
        pkill -TERM -x Spotify

        for _ in $(seq 1 40); do
          pgrep -xq Spotify || break
          sleep 0.5
        done

        if pgrep -xq Spotify; then
          echo "Spotify did not quit, so its autostart is unchanged" >&2
          exit 0
        fi
      fi

      # Rewritten in place rather than moved over, so the file keeps its
      # ownership and mode.
      edited=$(grep -v '^app\.autostart-mode=' "$prefs"; echo "$setting")
      printf '%s\n' "$edited" > "$prefs"

      if [[ "$running" == true ]]; then
        open -g -a Spotify
      fi
    '';

  # Fantastical's mini window lives in a helper that it registers to start at
  # login while "Run in background" is on, and that helper is what opens the
  # app proper. The setting is in the app group's suite, which `defaults`
  # resolves only from inside the sandbox, so it is written by path.
  fantasticalPreferences = "${home}/Library/Group Containers/85C27NK92C.com.flexibits.fantastical2.mac/Library/Preferences/85C27NK92C.com.flexibits.fantastical2.mac.plist";

  fantasticalBackground = pkgs.writeShellScript "fantastical-background" # bash
    ''
      set -euo pipefail

      PATH=/usr/bin:/bin:/usr/sbin:/sbin

      preferences=${lib.escapeShellArg fantasticalPreferences}

      if [[ ! -f "$preferences" ]]; then
        echo "Skipping Fantastical: it has not been run yet"
        exit 0
      fi

      [[ "$(defaults read "$preferences" RunInBackground 2>/dev/null)" == 1 ]] && exit 0

      echo "Setting Fantastical to run in the background..."
      defaults write "$preferences" RunInBackground -bool true
    '';
in
{
  system.activationScripts.postActivation.text = lib.mkAfter # bash
    ''
      for step in ${spotifyAutostart} ${fantasticalBackground}; do
        launchctl asuser "$(id -u -- ${lib.escapeShellArg user})" sudo --user=${lib.escapeShellArg user} -- "$step" \
          || echo "warning: $step failed" >&2
      done
    '';
}
