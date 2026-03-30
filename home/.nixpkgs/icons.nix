{ config, lib, pkgs, ... }:
let
  xdgDataHome = builtins.getEnv "XDG_DATA_HOME";
  assetsDir = "${xdgDataHome}/icons/assets";

  # A small C tool that sets custom icons on macOS app bundles via direct
  # POSIX file I/O — writing the Icon\r resource fork and FinderInfo xattr
  # by hand, completely bypassing NSWorkspace / osascript.  This sidesteps
  # TCC and com.apple.macl restrictions that block the NSWorkspace API when
  # run from a LaunchDaemon.
  #
  # Accepts both .icns and .png input; PNGs are wrapped in an icns container
  # on the fly (single ic10 entry — macOS downscales as needed).
  iconSetter = pkgs.stdenv.mkDerivation {
    name = "icon-setter";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      $CC -O2 -Wall -o $out/bin/icon-setter ${./pkgs/icon-setter.c}
    '';
  };

  script = pkgs.writeShellScriptBin "icon-customizer" ''
    echo ""
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] run started"

    results=$(mktemp /tmp/icon-customizer.XXXXXX)

    ${pkgs.fd}/bin/fd \
      --type=f '\.(icns|png)$' ${assetsDir} \
      --exec /bin/zsh -c '
        ts=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
        app="/Applications/$2.app"

        if [[ ! -d "$app" ]]; then
          exit 0
        fi

        setter=${iconSetter}/bin/icon-setter
        if [[ "$(stat -f %Su "$app")" == "root" ]]; then
          run=(sudo "$setter")
        else
          run=("$setter")
        fi

        if "''${run[@]}" "$app" "$1" 2>&1; then
          echo "[$ts] ok: $2"
          echo "$2" >> "'"$results"'"
        else
          echo "[$ts] FAILED: $2"
        fi
      ' zsh {} {/.}

    count=$(wc -l < "$results" 2>/dev/null | tr -d ' ')
    if [[ "$count" -gt 0 ]]; then
      apps=$(paste -sd, "$results" | sed 's/,/, /g')
      ${pkgs.terminal-notifier}/bin/terminal-notifier \
        -title "Icon Customizer" \
        -message "$count icon(s) updated: $apps"
    fi
    rm -f "$results"

    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] run finished"
  '';

  # A stable-path compiled wrapper so the agent can be granted Full Disk
  # Access once and the grant survives nix rebuilds (which change store
  # paths).  Must be a real Mach-O binary — TCC ignores FDA grants on
  # shell scripts (it evaluates /bin/bash instead of the script path).
  wrapper = pkgs.stdenv.mkDerivation {
    name = "icon-customizer-wrapper";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      $CC -O2 -Wall -o $out/bin/icon-customizer ${./pkgs/icon-customizer-wrapper.c}
    '';
  };
  wrapperPath = "/usr/local/bin/icon-customizer";
  logPath = "${xdgDataHome}/icons/launchd.log";
in
{
  environment.systemPackages = [ script ];


  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Install a stable-path compiled wrapper for icon-customizer.
    # Must be a Mach-O binary (not a script) so TCC recognises the FDA
    # grant on the path.  The agent's ProgramArguments points here so the
    # user only has to grant Full Disk Access once (System Settings →
    # Privacy & Security → Full Disk Access → add
    # /usr/local/bin/icon-customizer).
    mkdir -p /usr/local/bin
    cp ${wrapper}/bin/icon-customizer ${wrapperPath}
    chmod +x ${wrapperPath}

    # Passwordless sudo for icon-setter so the LaunchAgent can customise
    # icons on root-owned app bundles (e.g. Kandji-managed apps).
    # Must be a real file (not symlink) with mode 0440 for sudoers to accept it.
    echo "jamie ALL=(root) NOPASSWD: ${iconSetter}/bin/icon-setter" \
      > /etc/sudoers.d/icon-customizer
    chmod 0440 /etc/sudoers.d/icon-customizer
  '';

  # LaunchAgent (not Daemon) so the process runs in the user's login
  # session where FDA grants from System Settings actually apply.
  # All apps in /Applications are owned by the user, so root is not
  # needed — FDA alone is sufficient to write inside MACL'd bundles.
  launchd.user.agents.icon-customizer = {
    serviceConfig = {
      ProgramArguments = [ wrapperPath ];
      WatchPaths = [
        "/Applications"
        assetsDir
      ];
      RunAtLoad = true;
      StandardOutPath = logPath;
      StandardErrorPath = logPath;
      ThrottleInterval = 30;
    };
  };
}
