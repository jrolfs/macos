#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quit All and Restart
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔁
# @raycast.packageName System

# Restarting with apps still open lets loginwindow reopen them at login, and on
# macOS 26 locking its relaunch list did not stop that. Nothing is reopened if
# nothing is running, so this quits everything first.
#
# Quitting goes through Raycast's own command so its excluded-apps list still
# applies, and so unsaved documents get their usual save prompt rather than a
# signal.

open -g "raycast://extensions/raycast/system-actions/quit-all-apps"

# Each app is a block opening with a numbered `N) "Name"` line, and its type is
# a few lines further down.
foreground() {
  lsappinfo list | awk '
    match($0, /^ *[0-9]+\) "[^"]+"/) { name = substr($0, RSTART, RLENGTH); sub(/^ *[0-9]+\) "/, "", name); sub(/"$/, "", name) }
    /type="Foreground"/ { print name }
  '
}

# Done once the count has held for three seconds. An app sitting on a save
# prompt keeps it from settling at zero, so the count is all this waits on.
previous=-1
steady=0
for _ in {1..60}; do
  sleep 0.5
  current=$(foreground | wc -l)
  if [[ $current == $previous ]]; then
    (( steady++ ))
    (( steady >= 6 )) && break
  else
    steady=0
    previous=$current
  fi
done

# Anything still up besides Finder and Raycast is most likely sitting on a save
# prompt, and restarting would either be cancelled by it or lose the work. An
# app on Raycast's quit-all exclusion list would also stop here, and it has to
# be added below by hand: Raycast keeps that list in its encrypted database,
# where this cannot read it.
leftover=$(foreground | grep -vx -e Finder -e Raycast)
if [[ -n $leftover ]]; then
  echo "Still open: ${(j:, :)${(f)leftover}}"
  exit 1
fi

# kAERestart rather than kAEShowRestartDialog ('rrst'), which is the one that
# puts up the dialog with its reopen-windows checkbox. Apps still get a quit
# event and can cancel, but by now there are none left to ask.
osascript -e 'tell application "loginwindow" to «event aevtrest»'
