{ lib, ... }:

let
  sourceApp = "/Applications/Glide.app";
  targetApp = "/Applications/Glide Developer.app";
  bundleIdentifier = "app.glide-browser.glide.developer";
  bundleName = "Glide Developer";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Create "Glide Developer" — an independent copy of Glide with its own
    # bundle identifier so macOS treats it as a separate application (separate
    # preferences, data, history, etc.).
    if [[ -d "${sourceApp}" ]]; then
      echo "Creating ${targetApp} from ${sourceApp}..."
      rm -rf "${targetApp}"
      cp -a "${sourceApp}" "${targetApp}"

      /usr/libexec/PlistBuddy \
        -c "Set :CFBundleIdentifier ${bundleIdentifier}" \
        -c "Set :CFBundleName ${bundleName}" \
        "${targetApp}/Contents/Info.plist"

      codesign --force --deep --sign - "${targetApp}"
      echo "Created ${targetApp} (${bundleIdentifier})"
    else
      echo "Skipping Glide Developer: ${sourceApp} not found"
    fi
  '';
}
