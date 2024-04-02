{ config, lib, pkgs, ... }:
let
  script = pkgs.writeShellScriptBin "icon-customizer" ''
    #!/usr/bin/env zsh

    echo "\n\n\n$(date -u +"%Y-%m-%dT%H:%M:%SZ") / $(date)\n---------------------------------------------------" >> /var/log/apply.log

    ${pkgs.fd}/bin/fd --type=f '.*' ./assets --exec zsh -c 'fileicon set /Applications/$2.app $1 &>> /var/log/apply.log && echo "✅ $2" || echo "❌ $2"' zsh {} {/.}
  '';
in
{
  environment.systemPackages = with pkgs; [ script ];

  launchd.daemons.icon-customizer = {
    serviceConfig.ProgramArguments = [ "${script}/bin/icon-customizer" ];
    serviceConfig.KeepAlive = { PathState = { "/Applications" = true; }; };
    serviceConfig.RunAtLoad = true;
  };
}
