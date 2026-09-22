{ lib, pkgs, ... }:

let
  version = "0.14.0";

  # Kaset normally arrives as a Homebrew cask (see homebrew.nix, where the entry
  # is commented out). This builds the same release from source with one change:
  # WebKit's native picture in picture is switched on, so the "Enter Picture in
  # Picture" item in the video's context menu is usable instead of greyed out.
  # Drop this module and restore the cask once the patch is upstream.
  #
  # Built with the *system* Xcode toolchain rather than nixpkgs': the app needs
  # SwiftUI and FoundationModels, whose macro plugins (libPreviewsMacros,
  # libFoundationModelsMacros) ship only inside Xcode.app, plus actool and
  # xcstringstool for the asset catalogs and localization. Command Line Tools
  # alone is not enough — it carries just libObservationMacros and libSwiftMacros,
  # and @Generable then fails to expand.
  #
  # Same system-toolchain approach as sidecar.nix, and it likewise depends on
  # this host having `sandbox = false`: the builder reaches /usr/bin, and SwiftPM
  # resolves Sparkle over the network mid-build.
  kaset = pkgs.stdenvNoCC.mkDerivation {
    pname = "kaset";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "sozercan";
      repo = "kaset";
      tag = "v${version}";
      hash = "sha256-MBe2Fd0VkAYrc4oRLzRxC2gu2809Ey5G01BUVEJyslc=";
    };

    patches = [ ./pkgs/kaset-native-pip.patch ];

    postPatch = ''
      # version.env carries a placeholder that release CI overrides, so an
      # unmodified build reports itself as 1.0 and Sparkle's version comparison
      # becomes meaningless.
      substituteInPlace version.env \
        --replace-fail 'MARKETING_VERSION=1.0' 'MARKETING_VERSION=${version}'

      # Two flags the upstream script has no need for:
      #
      # --build-system native, because SwiftPM's "swiftbuild" engine (the
      # default as of Xcode 27) compiles asset catalogs itself and dies in
      # actool's IDE initialization ("A required plugin failed to load. ibtoold
      # failed IDE initialization"). build-app.sh drives actool by hand anyway,
      # and the native engine leaves catalogs alone.
      #
      # --disable-sandbox, because SwiftPM compiles Package.swift under its own
      # sandbox-exec, which a nix builder is not permitted to nest ("sandbox_apply:
      # Operation not permitted").
      #
      # Both call sites matter: the second is a --show-bin-path probe, and the
      # two engines report different output layouts.
      substituteInPlace Scripts/build-app.sh \
        --replace-fail 'swift build -c' 'swift build --build-system native --disable-sandbox -c'
    '';

    dontConfigure = true;

    # The bundle is code signed at the end of buildPhase. Letting fixupPhase
    # strip the Mach-O afterwards would break that seal, and macOS refuses to
    # launch a sandboxed app whose signature no longer matches.
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      # nix's stdenv points DEVELOPER_DIR and SDKROOT at a nix apple-sdk that has
      # no Swift toolchain, and DEVELOPER_DIR even poisons `xcode-select -p`.
      # Clearing it makes xcode-select report the real Xcode. See sidecar.nix.
      export DEVELOPER_DIR="$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p)"
      unset SDKROOT

      # build-app.sh calls swift, xcrun, codesign and install_name_tool by bare
      # name, and is written against the BSD userland.
      export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

      # SwiftPM wants somewhere to put its clone and artifact caches.
      export HOME="$TMPDIR"

      KASET_SIGNING=adhoc ./Scripts/build-app.sh release

      # Sparkle would find an update, then fail to apply it: the bundle it wants
      # to replace lives in the read-only store. Bump `version` above instead.
      # Editing Info.plist breaks the signature build-app.sh just applied, so
      # reseal the outer bundle with the same ad-hoc arguments it used.
      plist=.build/app/Kaset.app/Contents/Info.plist
      plutil -replace SUEnableAutomaticChecks -bool false "$plist"
      plutil -replace SUAllowsAutomaticUpdates -bool false "$plist"
      codesign --force --sign - --entitlements Kaset.entitlements .build/app/Kaset.app

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      cp -R .build/app/Kaset.app $out/Applications/

      runHook postInstall
    '';

    meta = {
      description = "Native macOS YouTube Music and YouTube client, patched for native picture in picture";
      homepage = "https://github.com/sozercan/kaset";
      platforms = lib.platforms.darwin;
    };
  };

in
{
  environment.systemPackages = [ kaset ];
}
