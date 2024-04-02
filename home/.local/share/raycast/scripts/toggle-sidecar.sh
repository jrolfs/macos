#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Sidecar Display
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🖥️

source "$(dirname $0)/../helpers/automator.sh"

setup toggle-sidecar

if [ $(system_profiler SPDisplaysDataType | grep -c "Sidecar Display") -gt 0 ]; then
  automator "$AUTOMATOR_WORKFLOWS/stop-mirroring-to-ipad.workflow"
  echo "Disconnected"
else
  automator "$AUTOMATOR_WORKFLOWS/mirror-to-ipad.workflow"
  echo "Connected"
fi
