{ inputs, lib, pkgs, ... }:

# "Glide Developer": an independent copy of Glide carrying its own bundle
# identifier, so macOS treats it as a separate application. That buys a distinct
# Dock tile, LaunchServices identity and preferences domain, and, because
# Firefox derives an install hash from the app path, its own default profile
# inside the ~/Library/Application Support/glide root the two share. The bundle
# identifier is not what separates the profiles; the [Install<hash>] section in
# that directory's profiles.ini is.

let
  bundleIdentifier = "app.glide-browser.glide.developer";
  bundleName = "Glide Developer";

  targetApp = "/Applications/${bundleName}.app";

  # Built through our own pkgs rather than taken from
  # inputs.glide.packages.<system>, which calls `import nixpkgs {}` itself and
  # would instantiate a second nixpkgs with none of this repo's config or
  # overlays. Same source tree either way; glide.nix's flake output is just a
  # callPackage of this file.
  glide = pkgs.callPackage "${inputs.glide}/package.nix" { };

  reidentify = pkgs.writeText "glide-reidentify.py" ''
    import os
    import pathlib
    import plistlib
    import sys

    app = pathlib.Path(sys.argv[1])
    identifier = os.environ["bundleIdentifier"]
    name = os.environ["bundleName"]

    info = app / "Contents" / "Info.plist"
    plist = plistlib.loads(info.read_bytes())
    plist["CFBundleIdentifier"] = identifier
    plist["CFBundleName"] = name
    info.write_bytes(plistlib.dumps(plist))

    # InfoPlist.strings is what macOS actually shows in the menu bar, and it
    # wins over CFBundleName. UTF-16 LE, which is what iconv was doing here
    # before this moved into a derivation.
    for strings in app.glob("Contents/Resources/*.lproj/InfoPlist.strings"):
        strings.write_text('CFBundleName = "%s";\n' % name, encoding="utf-16-le")
  '';

  bundle = pkgs.runCommand "glide-developer-${glide.version}"
    {
      inherit bundleIdentifier bundleName;
      nativeBuildInputs = [ pkgs.python3 ];

      # Same reason glide.nix and nixpkgs' firefox-bin set it: fixup would
      # strip and patch shebangs inside a signed application bundle.
      dontFixup = true;
    }
    ''
      mkdir -p "$out"
      cp -R "${glide}/Applications/Glide.app" "$out/$bundleName.app"
      chmod -R u+w "$out/$bundleName.app"

      python3 ${reidentify} "$out/$bundleName.app"

      # Rewriting Info.plist invalidated the Developer ID signature that sealed
      # it, so what is left behind is a broken signature rather than no
      # signature, and macOS refuses to launch that. Drop it and let activation
      # re-sign.
      rm -rf "$out/$bundleName.app/Contents/_CodeSignature"
    '';
in
{
  # The signing is the one step that cannot happen in a derivation: a valid
  # bundle signature needs _CodeSignature/CodeResources, and /usr/bin/codesign
  # is the only thing that writes one. nixpkgs has no rcodesign, and
  # darwin.sigtool signs bare Mach-O files only.
  #
  # The result is necessarily ad-hoc (`codesign -dv` reports `flags=0x2(adhoc)`,
  # `TeamIdentifier=not set`), because a second bundle identifier under Glide's
  # Developer ID would need Glide's signing key. 1Password's BrowserSupport
  # helper verifies the team id of whoever connects, so its extension will not
  # work in this copy; the Homebrew-installed Glide is the one for that.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Guarded on the store path so an unchanged Glide doesn't re-copy 315 MB and
    # re-sign it on every switch, which is what this did before.
    if [[ "$(cat /var/lib/glide-developer/source 2>/dev/null)" != "${bundle}" ]]; then
      echo "installing ${targetApp}..." >&2

      rm -rf "${targetApp}"
      cp -R "${bundle}/${bundleName}.app" "${targetApp}"
      chmod -R u+w "${targetApp}"

      # Nothing out of the store is quarantined, but the icon this app gets
      # below leaves FinderInfo and an Icon\r file behind, and a previous
      # generation's would make codesign refuse with "resource fork, Finder
      # information, or similar detritus not allowed".
      xattr -cr "${targetApp}"
      rm -f "${targetApp}/Icon"$'\r'

      codesign --force --deep --sign - "${targetApp}"

      # Written only once signing has succeeded, so a failure retries next
      # switch rather than being remembered as done.
      mkdir -p /var/lib/glide-developer
      printf '%s' "${bundle}" > /var/lib/glide-developer/source

      # Icon last, because fileicon-style writes invalidate the signature just
      # applied. Both Glide and this copy already fail `codesign --verify
      # --strict` for that reason, which is worth knowing but has not stopped
      # either from launching.
      #
      # icons.nix's LaunchAgent also watches /Applications and would pick this
      # up on its own; the explicit call just avoids waiting for it.
      #
      # $systemConfig, not /run/current-system: that symlink is not re-pointed
      # until the very end of activation, so resolving through it here would run
      # the *previous* generation's script.
      "$systemConfig/sw/bin/icon-customizer" || true
    fi
  '';
}
