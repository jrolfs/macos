#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Sidecar Display
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🖥️

source "$(dirname $0)/../helpers/automator.sh"

if [ $(system_profiler SPDisplaysDataType | grep -c "Sidecar Display") -gt 0 ]; then
  echo "Disconnecting..."
  automator "$AUTOMATOR_WORKFLOWS/stop-mirroring-to-ipad.workflow"
else
  echo "Connecting"
  automator "$AUTOMATOR_WORKFLOWS/mirror-to-ipad.workflow"
fi
