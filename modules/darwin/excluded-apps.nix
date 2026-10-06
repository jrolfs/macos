# Per-host application exclusions — typically apps installed by organization
# device management. Keyed on the short hostname, and read by both
# homebrew.nix (casks) and mas.nix (App Store apps), which is why it lives
# here rather than in either of them.
#
# Names match the cask token or the App Store app name as written in those
# files, so an entry can cover both.

{
  # Xcode is a many-GB mas install; skip it during provisioning and add it
  # by hand (or drop this entry) when it's actually needed.
  ala = [];
  # Work machine, MDM-managed. Kandji installs apps directly into
  # /Applications, and a cask refuses to clobber an app it doesn't own, which
  # is what failed the first switch here.
  #
  # 1Password is no longer excluded. Kandji enforces it by *version check*
  # rather than by owning the bundle, so a brew-managed copy at or above the
  # required version satisfies it and it stops reinstalling. That reinstall
  # was the problem: it moved the GUI while `op` (the separate `1password-cli`
  # cask) stayed put, and 1Password couples the two tightly enough that the
  # skew breaks the CLI's desktop-app integration. One owner for both halves
  # means they move together. See the greedy note in homebrew.nix, and run the
  # one-time `brew install --cask --adopt 1password` to take over Kandji's
  # existing copy.
  #
  # Xcode is no longer excluded here: kaset.nix builds Kaset from source on
  # this host, and that needs the Swift macro plugins and actool that only
  # ship inside Xcode.app.
  adrian = [ "zoom" ];
  newt = [ "Xcode" "zoom" ];
  orolo = [ "google-chrome" "Xcode" "zoom" ];
  yours-truly = [ "Xcode" ];
}
