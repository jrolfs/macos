{ pkgs, ... }:

let
  # A self-contained CLI to manage Sidecar (iPad-as-display) sessions by
  # driving the private SidecarCore.framework directly — no UI automation,
  # no AppleScript, no "Watch Me Do".  Connection state is read from the
  # framework itself (SidecarDisplayManager.connectedDevices), so `toggle`
  # and `status` are reliable without sniffing display names.
  #
  #   sidecar devices | connected
  #   sidecar status     <name>
  #   sidecar connect    <name> [-wired]
  #   sidecar disconnect <name>
  #   sidecar toggle     <name> [-wired]
  #
  # Compiled with the *system* Swift toolchain via xcrun: SidecarCore is an
  # Apple private framework that only exists in the macOS SDK, and the nix
  # sandbox is disabled on this host, so reaching the system toolchain here
  # is consistent with how icons.nix builds icon-setter.c with $CC.
  sidecar = pkgs.stdenv.mkDerivation {
    name = "sidecar";
    version = "1.0.0";
    dontUnpack = true;

    # nix's stdenv points DEVELOPER_DIR/SDKROOT at a nix-provided apple-sdk
    # that has no swiftc.  Clear DEVELOPER_DIR so xcode-select reports the
    # *real* persisted toolchain (Command Line Tools / Xcode), point xcrun at
    # it, and drop the nix SDKROOT so swiftc resolves the system macOS SDK.
    buildPhase = ''
      export DEVELOPER_DIR="$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p)"
      unset SDKROOT
      /usr/bin/xcrun --sdk macosx swiftc -O ${./pkgs/sidecar.swift} -o sidecar
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp sidecar $out/bin/sidecar
    '';
  };
in
{
  environment.systemPackages = [ sidecar ];
}
