{ config, lib, pkgs, ... }:
let
  xdgDataHome = builtins.getEnv "XDG_DATA_HOME";
  assetsDir = "${xdgDataHome}/icons/assets";

  fileicon = pkgs.stdenv.mkDerivation {
    name = "fileicon";

    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/mklement0/fileicon/6508d97ed46e96698e4af9ca44d6666ac29a8cf0/bin/fileicon";
      sha256 = "0jq6c1k4h0d4vzbbzyxbpdcyg7kvhy5jxkiykjpz4g9d5436657d";
    };

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/fileicon
      chmod +x $out/bin/fileicon

      # Patch out the -w permission pre-check — on macOS, access(W_OK)
      # returns false for root when com.apple.macl xattrs are present,
      # even though root can actually write.
      sed -i 's/-w \$targetFileOrFolder/true/' $out/bin/fileicon

      # Replace bare `|| die` calls with descriptive messages and stop
      # swallowing osascript errors (>/dev/null)
      sed -i 's#>/dev/null || die$#|| die "osascript failed for: $targetFileOrFolder"#' $out/bin/fileicon
      sed -i 's# || die$# || die "failed in ''${FUNCNAME[0]:-main} for: $targetFileOrFolder"#' $out/bin/fileicon
    '';
  };

  script = pkgs.writeShellScriptBin "icon-customizer" ''
    echo ""
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] run started"

    ${pkgs.fd}/bin/fd \
      --type=f '.*' ${assetsDir} \
      --exec /bin/zsh -c '
        ts=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
        app="/Applications/$2.app"

        if [[ ! -d "$app" ]]; then
          exit 0
        fi

        # Temporarily strip com.apple.macl — this mandatory access control
        # xattr causes both access(W_OK) and NSWorkspace file writes to
        # fail, even for root. Save and restore it after the icon is set.
        macl=$(xattr -px com.apple.macl "$app" 2>/dev/null)
        xattr -d com.apple.macl "$app" 2>/dev/null

        if ${fileicon}/bin/fileicon set "$app" "$1" 2>&1; then
          echo "[$ts] ok: $2"
        else
          echo "[$ts] FAILED: $2"
        fi

        if [[ -n "$macl" ]]; then
          xattr -wx com.apple.macl "$macl" "$app" 2>/dev/null
        fi
      ' zsh {} {/.}

    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] run finished"
  '';
in
{
  environment.systemPackages = [ script ];

  launchd.daemons.icon-customizer = {
    serviceConfig = {
      ProgramArguments = [ "${script}/bin/icon-customizer" ];
      WatchPaths = [
        "/Applications"
        assetsDir
      ];
      RunAtLoad = true;
      StandardOutPath = "/var/log/icon-customizer.log";
      StandardErrorPath = "/var/log/icon-customizer.log";
      ThrottleInterval = 300;
    };
  };
}
