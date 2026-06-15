#!/usr/bin/env zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Sidecar Display
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🖥️

# Toggles a Sidecar session with the "Leto" iPad via the `sidecar` CLI, which
# drives the private SidecarCore framework directly (no Automator / "Watch Me
# Do" UI replay). `sidecar` is built and installed by home/.nixpkgs/sidecar.nix.

if output=$(sidecar toggle "Leto" 2>&1); then
  echo "Leto ${output}"
else
  echo "Sidecar error: ${output}"
fi
