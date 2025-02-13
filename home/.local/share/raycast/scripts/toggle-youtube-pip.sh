#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle YouTube Picture-in-Picture
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📺

source "$(dirname $0)/../helpers/automator.sh"

setup toggle-youtube-picture-in-picture

run_automator "toggle-youtube-picture-in-picture"

echo "Toggled Picture-in-Picture"
