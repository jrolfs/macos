{ config, pkgs, ... }:

let
  # Import the icon file into the Nix store
  customIcon = pkgs.runCommand "vscode-icon" {} ''
    mkdir -p $out
    cp ${./icons/visual-studio-code.icns} "$out/icon.icns"
  '';

  # App bundle names
  oldName = "VSCodium";
  newName = "Codium";

  # Helper app names
  helpers = [
    "${oldName} Helper"
    "${oldName} Helper (GPU)"
    "${oldName} Helper (Plugin)"
    "${oldName} Helper (Renderer)"
  ];

  # Get the extension
  extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "sync-settings";
      publisher = "zokugun";
      version = "0.2.5";
      sha256 = "sha256-l7Szv4ttXowxuGvssRzvel6vX8uVD4J7DlXJ79I7b8Q=";
    }
  ];

  codium = pkgs.vscodium.overrideAttrs (oldAttrs: {
    postInstall = ''
      ${oldAttrs.postInstall or ""}

      # Get the app bundle path in $out
      APP_PATH="$out/Applications/${oldName}.app"

      # Rename and update helper apps
      cd "$APP_PATH/Contents/Frameworks"
      for helper in ${builtins.toString (map (h: ''"${h}"'') helpers)}; do
        newHelper=''${helper/${oldName}/${newName}}
        cp -R "$helper.app" "$newHelper.app"
        # /usr/libexec/PlistBuddy -c "Set :CFBundleName $newHelper" "$newHelper.app/Contents/Info.plist"
        # /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $newHelper" "$newHelper.app/Contents/Info.plist"
      done

      # Rename the main app bundle
      cd "$out/Applications"
      mv "${oldName}.app" "${newName}.app"
      APP_PATH="$out/Applications/${newName}.app"

      # Replace the icon file
      cp "${customIcon}/icon.icns" "$APP_PATH/Contents/Resources/${newName}.icns"

      # Update the main bundle's Info.plist
      /usr/libexec/PlistBuddy -c "Set :CFBundleName ${newName}" "$APP_PATH/Contents/Info.plist"
      /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${newName}" "$APP_PATH/Contents/Info.plist"
      /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ${newName}" "$APP_PATH/Contents/Info.plist"

      # Install extensions
      mkdir -p "$APP_PATH/Contents/Resources/app/extensions"
      ${builtins.toString (map (ext: ''
        cp -r "${ext.outPath}/share/vscode/extensions/${ext.vscodeExtUniqueId}" "$APP_PATH/Contents/Resources/app/extensions/"
      '') extensions)}

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
    if [ -d "/Applications/Nix Apps/${newName}.app" ]; then
      echo "Re-signing ${newName}.app and helpers..."

      # Sign helper apps first
      for helper in ${toString (map (h: ''"${h}"'') (map (h: builtins.replaceStrings [oldName] [newName] h) helpers))}; do
        echo "Signing $helper..."
        codesign --force --deep --sign - "/Applications/Nix Apps/${newName}.app/Contents/Frameworks/$helper.app"
      done

      # Sign the main app bundle last
      echo "Signing main app bundle..."
      codesign --force --deep --sign - "/Applications/Nix Apps/${newName}.app"
    fi
  '';
}
