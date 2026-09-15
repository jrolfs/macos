{ lib, ... }:

{
  # Control Spotlight indexing
  #
  # Currently have been using Raycast 2's native search index, so don't
  # necessarily need this for file search, but there are a few catches:
  #
  # 1. `mas list` uses the Spotlight index, so if it's disabled `mas` will
  # reinstall every specified `mas` app on every `switch`
  # 2. It's nice every once in a while to just search a directory in Finder,
  # especially Trash
  #
  #
  # # Explanation of `mas` mechanism/symptom
  #
  # It has to be on because `mas list` enumerates installed App Store apps purely
  # from Spotlight's kMDItemAppStoreAdamID attribute, and with indexing off it
  # finds nothing while still exiting 0. `brew bundle` reads that empty list,
  # concludes every `homebrew.masApps` entry is missing, and reinstalls all of
  # them on every switch, which is what makes the App Store interrupt a rebuild
  # to demand you quit Fantastical and friends.
  #
  #
  # # Why it must be controlled this way
  #
  # Spotlight indexing has no nix-darwin option and its store under
  # /System/Volumes/Data/.Spotlight-V100 is root-only with SIP enabled, so
  # driving `mdutil` is the only way to set it.
  #
  # Runs in preActivation rather than postActivation (where nix-darwin's own
  # hydra example puts its `mdutil` call) because the homebrew phase runs before
  # postActivation and would otherwise read a stale index.
  #
  # `mdutil -i on` is idempotent and takes several volumes, so this needs no
  # guard. /usr/bin is off the activation PATH and the script runs under
  # `set -e`, hence the absolute path and the `|| true`. /nix is a separate
  # nobrowse APFS volume with no Spotlight store, so it stays out of the crawl
  # without being named here.
  #
  system.activationScripts.preActivation.text = lib.mkAfter ''
    /usr/bin/mdutil -i on / /System/Volumes/Data >/dev/null || true
  '';
}
