#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Sidecar Display
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🖥️

source "$(dirname $0)/../helpers/automator.sh"

setup toggle-sidecar

if [ $(system_profiler SPDisplaysDataType | grep -c "Sidecar Display") -gt 0 ]; then
  run_automator "stop-mirroring-to-ipad"
  echo "Disconnected"
else
  run_automator "mirror-to-ipad"
  echo "Connected"
fi
