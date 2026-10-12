{ lib, stdenvNoCC, fetchzip }:

# Phosphor's icon fonts. nixpkgs doesn't package them, and the npm package
# for the web build is the only release that ships the TTFs, one per weight.
# The families are "Phosphor" for the regular weight and "Phosphor-<Weight>"
# for the rest; each icon's codepoint is in that weight's style.css.

stdenvNoCC.mkDerivation rec {
  pname = "phosphor-icons";
  version = "2.1.2";

  src = fetchzip {
    url = "https://registry.npmjs.org/@phosphor-icons/web/-/web-${version}.tgz";
    hash = "sha256-iaNtM6lLYY3Shtbk712DWqayGIi/iofoASCysZqm3Kc=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/fonts/truetype src/*/*.ttf
    runHook postInstall
  '';

  meta = {
    description = "Phosphor icon family, as fonts";
    homepage = "https://phosphoricons.com";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
