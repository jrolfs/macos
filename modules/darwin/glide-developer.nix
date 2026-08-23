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

      # Update the localized display name (UTF-16 LE file that macOS uses for
      # the menu bar title, overriding CFBundleName from Info.plist).
      for lproj in "${targetApp}"/Contents/Resources/*.lproj; do
        strings_file="$lproj/InfoPlist.strings"
        if [[ -f "$strings_file" ]]; then
          printf 'CFBundleName = "%s";\n' "${bundleName}" \
            | iconv -f UTF-8 -t UTF-16LE > "$strings_file"
        fi
      done

      # Strip custom icon detritus copied from source — codesign rejects
      # resource forks and FinderInfo ("resource fork, Finder information,
      # or similar detritus not allowed").
      rm -f "${targetApp}/Icon"$'\r'
      xattr -cr "${targetApp}"

      codesign --force --deep --sign - "${targetApp}"
      echo "Created ${targetApp} (${bundleIdentifier})"

      # Apply custom icon if available (icon-customizer is built by icons.nix).
      #
      # $systemConfig, not /run/current-system: that symlink is not re-pointed
      # until the very end of activation, so resolving through it here runs the
      # *previous* generation's script. Any change to icon-customizer would then
      # appear to have no effect until the switch after the one that made it.
      # (The LaunchAgent wrapper is the opposite case and correctly keeps
      # /run/current-system — it runs after activation, and its content has to
      # stay byte-identical across rebuilds or the Full Disk Access grant on
      # /usr/local/bin/icon-customizer is invalidated.)
      "$systemConfig/sw/bin/icon-customizer" || true
    else
      echo "Skipping Glide Developer: ${sourceApp} not found"
    fi
  '';
}
