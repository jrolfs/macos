{ config, lib, pkgs, userName, ... }:
let
  # Hardcoded because builtins.getEnv returns "" under pure flake eval.
  xdgDataHome = "/Users/${userName}/.local/share";
  logPath = "${xdgDataHome}/spicetify/launchd.log";

  script = pkgs.writeShellScriptBin "spicetify-watcher" ''
    mkdir -p "${xdgDataHome}/spicetify"

    echo ""
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] Spotify.app changed — applying spicetify customization"

    if ${pkgs.spicetify-cli}/bin/spicetify backup apply 2>&1; then
      echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] spicetify applied successfully"
    else
      echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] spicetify FAILED"
    fi
  '';
in
{
  launchd.user.agents.spicetify-watcher = {
    serviceConfig = {
      ProgramArguments = [ "${script}/bin/spicetify-watcher" ];
      WatchPaths = [
        "/Applications/Spotify.app"
      ];
      RunAtLoad = true;
      StandardOutPath = logPath;
      StandardErrorPath = logPath;
      ThrottleInterval = 30;
    };
  };
}
