{ pkgs, lib, config, userName, ... }:

# The `jrolfs/tap` casks, and the tool that bumps them.
#
# `homebrew/` in this repo *is* the tap: activation symlinks it into
# Library/Taps, so brew reads the working tree directly and an edit is live on
# the next switch with nothing to push first.
#
# It used to be a copy. `homebrew.taps` named `jrolfs/tap` with no
# clone_target, so brew cloned github.com/jrolfs/homebrew-tap and read that,
# while `cask-updater` rewrote the files here — two copies, no sync, drifting
# in both directions. They did: the clone was a lingon-pro bump ahead while
# this tree was a unite-pro fix ahead, and a switch kept failing a checksum
# that had already been corrected in the only place anyone was looking.
#
# Verified before adopting: brew reads casks from a symlinked, non-git tap
# (`brew info --cask jrolfs/tap/unite-pro` resolves and reports upgrades), and
# `brew tap jrolfs/tap` against the existing directory is a no-op that leaves
# the symlink alone — which is what `brew bundle` does every activation.
# `jrolfs/tap` therefore stays in `homebrew.taps`, so the Brewfile lists it and
# cleanup = "zap" doesn't untap it.

let
  tapPath = "${config.homebrew.prefix}/Library/Taps/jrolfs/homebrew-tap";
  tapSource = "/Users/${userName}/.config/system/homebrew";

  script = pkgs.writeShellScriptBin "cask-updater" ''
    set -euo pipefail

    tap_dir="''${NIX_CONFIG_DIR:-$HOME/.config/system}/homebrew"

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

  # Before the Homebrew bundle, which is why this is extraActivation: that
  # runs early (offset ~29k in the activation script) while the bundle is at
  # ~128k.
  system.activationScripts.extraActivation.text = lib.mkIf config.homebrew.enable (
    lib.mkAfter # bash
      ''
        if [ "$(readlink ${tapPath} 2>/dev/null)" != ${tapSource} ]; then
          # A directory here is the old cloned tap. Removing it loses nothing:
          # its history is on GitHub, and this repo is the source now. Guarded
          # on .git so a symlink-to-elsewhere or a stray file is left for a
          # human rather than deleted silently.
          if [ -d ${tapPath} ] && [ ! -L ${tapPath} ]; then
            if [ -e ${tapPath}/.git ]; then
              echo >&2 "homebrew: replacing the cloned jrolfs/tap with this repo's homebrew/"
              rm -rf ${tapPath}
            else
              echo >&2 "homebrew: ${tapPath} is a directory but not a tap clone — leaving it alone"
            fi
          else
            rm -f ${tapPath}
          fi

          if [ ! -e ${tapPath} ]; then
            mkdir -p "$(dirname ${tapPath})"
            ln -s ${tapSource} ${tapPath}
          fi
        fi
      ''
  );
}
