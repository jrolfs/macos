{ lib, ... }:

# Spotlight indexing, kept on.
#
# Raycast is the daily search, so file search is not what this is protecting.
# Two other things depend on the index:
#
# 1. `mas list` enumerates installed App Store apps purely from Spotlight's
#    kMDItemAppStoreAdamID attribute. With indexing off it finds nothing while
#    still exiting 0, so mas.nix concludes every app in its list is missing and
#    runs `mas install` for all of them on every switch. The App Store then
#    interrupts the rebuild to demand you quit Fantastical and friends.
# 2. Searching a directory from Finder, Trash especially, which nothing else
#    covers.
#
# Spotlight indexing has no nix-darwin option, and its store under
# /System/Volumes/Data/.Spotlight-V100 is root-only with SIP enabled, so driving
# `mdutil` is the only way to set it.
#
# preActivation rather than postActivation (where nix-darwin's own hydra example
# puts its `mdutil` call) because both the Homebrew phase and mas.nix's
# activation script run before postActivation and would otherwise read a stale
# index.
#
# `mdutil -i on` is idempotent and takes several volumes, so this needs no
# guard. /usr/bin is off the activation PATH and the script runs under `set -e`,
# hence the absolute path and the `|| true`. /nix is a separate nobrowse APFS
# volume with no Spotlight store, so it stays out of the crawl without being
# named here.

{
  system.activationScripts.preActivation.text = lib.mkAfter ''
    /usr/bin/mdutil -i on / /System/Volumes/Data >/dev/null || true
  '';
}
