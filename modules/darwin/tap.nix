{ pkgs, ... }:

let
  script = pkgs.writeShellScriptBin "cask-updater" ''
    set -euo pipefail

    tap_dir="''${HOMESHICK_KINGDOM:-$HOME/.homesick/repos}/macos/homebrew"

    if [[ ! -d "$tap_dir/Casks" ]]; then
      echo "error: tap directory not found: $tap_dir/Casks" >&2
      exit 1
    fi

    update_cask() {
      local rb="$1"
      local name
      name=$(basename "$rb" .rb)

      # Parse version, sha256, and URL from the cask .rb file
      local current_version current_sha url_template
      current_version=$(sed -n 's/.*version "\([^"]*\)".*/\1/p' "$rb")
      current_sha=$(sed -n 's/.*sha256 "\([^"]*\)".*/\1/p' "$rb")
      url_template=$(sed -n 's/.*url "\([^"]*\)".*/\1/p' "$rb")

      if [[ -z "$current_version" || -z "$current_sha" || -z "$url_template" ]]; then
        echo "  skip: could not parse $name.rb"
        return
      fi

      # Resolve Homebrew Ruby version interpolations in the URL
      local major minor patch url
      major=$(echo "$current_version" | cut -d. -f1)
      minor=$(echo "$current_version" | cut -d. -f2)
      patch=$(echo "$current_version" | cut -d. -f3)

      url="$url_template"
      url="''${url//'#{version.major}'/$major}"
      url="''${url//'#{version.minor}'/$minor}"
      url="''${url//'#{version.patch}'/$patch}"
      url="''${url//'#{version}'/$current_version}"

      echo "  url: $url"

      local tmpdir
      tmpdir=$(mktemp -d)
      trap 'rm -rf "$tmpdir"' RETURN

      if ! curl -fsSL "$url" -o "$tmpdir/download.zip"; then
        echo "  error: download failed" >&2
        return 1
      fi

      local new_sha
      new_sha=$(shasum -a 256 "$tmpdir/download.zip" | cut -d' ' -f1)

      if [[ "$new_sha" = "$current_sha" ]]; then
        echo "  up to date ($current_version)"
        return
      fi

      unzip -q "$tmpdir/download.zip" -d "$tmpdir/extracted"

      local app_path
      app_path=$(find "$tmpdir/extracted" -maxdepth 2 -name "*.app" -type d | head -1)

      if [[ -z "$app_path" ]]; then
        echo "  error: no .app found in archive" >&2
        return 1
      fi

      local new_version
      new_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
        "$app_path/Contents/Info.plist" 2>/dev/null)

      if [[ -z "$new_version" ]]; then
        echo "  error: could not read version from app bundle" >&2
        return 1
      fi

      local new_major
      new_major=$(echo "$new_version" | cut -d. -f1)
      if [[ "$new_major" != "$major" ]] && [[ "$url_template" == *'#{version.major}'* ]]; then
        echo "  warning: major version changed ($major -> $new_major), URL uses major version"
      fi

      local tmp
      tmp=$(mktemp)
      sed -e "s|version \"$current_version\"|version \"$new_version\"|" \
          -e "s|sha256 \"$current_sha\"|sha256 \"$new_sha\"|" \
          "$rb" > "$tmp" && mv "$tmp" "$rb"

      echo "  updated: $current_version -> $new_version"
    }

    echo "Updating casks in $tap_dir/Casks..."
    echo ""

    for rb in "$tap_dir"/Casks/*.rb; do
      [[ -f "$rb" ]] || continue
      echo "$(basename "$rb" .rb):"
      update_cask "$rb"
      echo ""
    done

    echo "Done."
  '';
in
{
  environment.systemPackages = [ script ];
}
