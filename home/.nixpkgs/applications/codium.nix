{ config, pkgs, ... }:

let
  # Import the icon file into the Nix store
  customIcon = pkgs.runCommand "vscode-icon" {} ''
    mkdir -p $out
    cp ${./icons/visual-studio-code.icns} "$out/icon.icns"
  '';

  codium = pkgs.vscodium.overrideAttrs (oldAttrs: {
    postInstall = ''
      ${oldAttrs.postInstall or ""}

      # Get the app bundle path in $out
      APP_PATH="$out/Applications/VSCodium.app"

      # Rename helper apps first
      cd "$APP_PATH/Contents/Frameworks"
      mv "VSCodium Helper.app" "Codium Helper.app"
      mv "VSCodium Helper (GPU).app" "Codium Helper (GPU).app"
      mv "VSCodium Helper (Plugin).app" "Codium Helper (Plugin).app"
      mv "VSCodium Helper (Renderer).app" "Codium Helper (Renderer).app"

      # Rename the main app bundle
      cd "$out/Applications"
      mv "VSCodium.app" "Codium.app"
      APP_PATH="$out/Applications/Codium.app"

      # Replace the icon file
      cp "${customIcon}/icon.icns" "$APP_PATH/Contents/Resources/Codium.icns"

      # Update the bundle identifier, name, and icon reference
      /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Codium" "$APP_PATH/Contents/Info.plist"
      /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Codium" "$APP_PATH/Contents/Info.plist"

      # Touch the app bundle to refresh the icon cache
      touch "$APP_PATH"
    '';

    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
      pkgs.makeWrapper
    ];
  });
in
{
  environment.systemPackages = [ codium ];

  system.activationScripts.postActivation.text = ''
    # Re-sign Codium after modifications
    if [ -d "/Applications/Nix Apps/Codium.app" ]; then
      echo "Re-signing Codium.app..."
      codesign --force --deep --sign - "/Applications/Nix Apps/Codium.app"
    fi
  '';
}
