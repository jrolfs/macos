#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle 📱
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName Sidecar

# Toggles the "Leto" iPad's Sidecar session via the `sidecar` CLI (which talks to
# the private SidecarCore framework — no Automator / "Watch Me Do"). Built and
# installed by home/.nixpkgs/sidecar.nix. Arrangement lives in the separate
# "Arrange Sidecar Display" command (sidecar-arrange.sh).

# Ensure the nix system profile (where `sidecar` lives) is on PATH regardless of
# how Raycast invokes the script.
export PATH="/run/current-system/sw/bin:$PATH"

if output=$(sidecar toggle "Leto" 2>&1); then
  echo "Leto ${output}"
else
  echo "Sidecar error: ${output}"
fi
