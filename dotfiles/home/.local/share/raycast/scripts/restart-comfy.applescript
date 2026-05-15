#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart ComfyUI
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄
# @raycast.packageName System

# Documentation:
# @raycast.description Restarts the ComfyUI application
# @raycast.author YourName
# @raycast.authorURL https://github.com/yourusername

tell application "System Events"
  set isRunning to (count of (every process whose name is "ComfyUI")) > 0
end tell

if isRunning then
  tell application "ComfyUI"
    quit
  end tell

  delay 1

  tell application "ComfyUI"
    activate
  end tell

  return "Successfully restarted ComfyUI"
else
  tell application "ComfyUI"
    activate
  end tell

  return "Started ComfyUI (it wasn't running)"
end if
