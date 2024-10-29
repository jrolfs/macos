{ pkgs, ... }:

let
  fileicon = pkgs.stdenv.mkDerivation {
    name = "fileicon";
    version = "0.3.4";

    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/mklement0/fileicon/6508d97ed46e96698e4af9ca44d6666ac29a8cf0/bin/fileicon";
      sha256 = "0jq6c1k4h0d4vzbbzyxbpdcyg7kvhy5jxkiykjpz4g9d5436657d";
    };

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/fileicon
      chmod +x $out/bin/fileicon
    '';
  };
in
{
  environment.systemPackages = [ fileicon ];
}
