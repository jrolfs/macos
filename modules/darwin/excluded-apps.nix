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
  ala = [ "Xcode" ];
  newt = [ "Xcode" "zoom" ];
  orolo = [ "google-chrome" "Xcode" "zoom" ];
  yours-truly = [ "Xcode" ];
}
