{ config, lib, pkgs, ... }:
let
  xdgDataHome = builtins.getEnv "XDG_DATA_HOME";
  logs = "${xdgDataHome}/icons/apply.log";
  fileiconSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/mklement0/fileicon/6508d97ed46e96698e4af9ca44d6666ac29a8cf0/bin/fileicon";
    sha256 = "0jq6c1k4h0d4vzbbzyxbpdcyg7kvhy5jxkiykjpz4g9d5436657d";
  };

  fileicon = pkgs.stdenv.mkDerivation {
    name = "fileicon";
    buildInputs = [ pkgs.makeWrapper ];

    src = fileiconSource;

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/fileicon
      chmod +x $out/bin/fileicon
      wrapProgram $out/bin/fileicon --run "cd $out/bin"
    '';
  };

  script = pkgs.writeShellScriptBin "icon-customizer" ''
    #!/usr/bin/env zsh
    echo -e "\n\n\n$(date) $(whoami)@$(id -gn)---------------------------------------------------\n" >> ${logs}

    ${pkgs.fd}/bin/fd \
      --type=f '.*' ${xdgDataHome}/icons/assets \
      --exec zsh -c ' ${fileicon}/bin/fileicon set /Applications/$2.app $1 >> ${logs} 2>&1' zsh {} {/.}
  '';
in
{
  environment.systemPackages = with pkgs; [ script ];

  # launchd.daemons.icon-customizer = {
  #   serviceConfig.UserName = "root";
  #   serviceConfig.GroupName = "wheel";
  #   serviceConfig.ProgramArguments = [ "${script}/bin/icon-customizer" ];
  #   serviceConfig.WatchPaths = ["/Applications"];
  # };
}
