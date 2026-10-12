{ config, lib, pkgs, ... }:

# Pegasus, the game menu, and what it reads.
#
# Each system's collection (its name, file extensions and RetroArch launch
# line) is written by Nix as the header of that system's metadata.pegasus.txt,
# in the ROM directory itself. That file is also where arcade-scrape's
# Skyscraper writes game metadata and media paths, underneath the header,
# and Skyscraper keeps whatever header it finds. One file per system, one
# collection per system, with no second definition for Pegasus to merge or
# show twice. arcade-collections rewrites the headers at boot and on every
# switch, so a changed core or extension list reaches files that already have
# scraped games in them.
#
# The theme is Pegasus's own default, pegasus-theme-grid, recolored from
# modules/theme/palette.nix. It ships in Pegasus's source tree, so it is
# maintained alongside Pegasus itself and already built for a TV and a
# controller; recoloring it is a table of substitutions where a new theme
# would be thousands of lines of QML to keep working.

let
  cfg = config.arcade;
  systems = import ./systems.nix;
  palette = (import ../../theme/palette.nix).dark.soft;
  fonts = import ../../theme/fonts.nix;

  home = config.users.users.arcade.home;
  configDirectory = "${home}/.config/pegasus-frontend";

  # Every literal color in pegasus-theme-grid, and what it becomes. The
  # theme has no theming layer of its own, so this table is the whole of it.
  # Translucent blacks keep their alpha and take the palette's darkest
  # background, so overlays tint toward the palette rather than toward black.
  colors = {
    "#eee" = palette.fg0;
    "#bbb" = palette.grey2;
    "#aaa" = palette.grey2;
    "#999" = palette.grey1;
    "#808080" = palette.grey1;
    "#666" = palette.grey0;
    "#444" = palette.bg3;
    "#333" = palette.bg1;
    "#222" = palette.bg0;
    "#111" = palette.bg_dim;
    "#000" = palette.bg_dim;

    # Focus, selection and labels: one accent, readable from a couch.
    "#4ae" = palette.yellow;
    "#0074da" = palette.yellow;
    "#0870aa" = palette.yellow;

    "#d22" = palette.red;
    "#ff6235" = palette.orange;

    # The platform card behind each system's logo, and its subtitle.
    "#ff4035" = palette.bg_visual_yellow;
    "#faa" = palette.yellow;

    "#00000000" = "#00${lib.removePrefix "#" palette.bg_dim}";
    "#50000000" = "#50${lib.removePrefix "#" palette.bg_dim}";
    "#60000000" = "#60${lib.removePrefix "#" palette.bg_dim}";
    "#cc000000" = "#cc${lib.removePrefix "#" palette.bg_dim}";
  };

  # The theme's fonts, radii and opacities, written once as a QML singleton
  # (Style.qml) that the edited theme reads. Out of the box it names
  # Pegasus's bundled Roboto and repeats each number at every use.
  style = {
    sans = fonts.sans.family;
    # One corner radius where the original had 3 and 4 pixels.
    radius = 4;
    # An unfocused system's logo, and the grey veil over a game whose file
    # is missing.
    dimmed = 0.3;
    missing = 0.4;
    # The shade behind the filter panel, and the game details panel.
    shade = 0.25;
    panel = 0.85;
  };

  styleSingleton = pkgs.writeText "Style.qml" ''
    pragma Singleton
    import QtQuick 2.0

    QtObject {
      readonly property string sans: "${style.sans}"
      readonly property real radius: ${toString style.radius}
      readonly property real dimmed: ${toString style.dimmed}
      readonly property real missing: ${toString style.missing}
      readonly property real shade: ${toString style.shade}
      readonly property real panel: ${toString style.panel}
    }
  '';

  theme = pkgs.runCommandLocal "pegasus-theme-gruvbox-material" { } ''
    cp -r ${pkgs.pegasus-frontend.src}/src/themes/pegasus-theme-grid $out
    chmod -R u+w $out
    cd $out

    # Quoted on both sides, so "#000" can't match inside "#00000000".
    find . -name '*.qml' -exec sed -i \
      ${lib.concatStringsSep " \\\n      " (lib.mapAttrsToList
        (from: to: "-e 's/\"${from}\"/\"${to}\"/g'")
        colors)} \
      {} +

    # Not Theme.qml, which would be the obvious name: Pegasus's entry point is
    # theme.qml, and the two are one file on a case-insensitive filesystem.
    cp ${styleSingleton} Style.qml
    echo 'singleton Style 1.0 Style.qml' > qmldir

    # Every file that uses a font or one of those values sits one directory
    # down, and a singleton only resolves through an explicit import.
    for file in layer_*/*.qml; do
      sed -i '0,/^import QtQuick/s//import ".."\n&/' "$file"
    done

    # Geist has no condensed cut; the system names use the regular one.
    sed -i -e 's/globalFonts\.sans/Style.sans/' -e 's/globalFonts\.condensed/Style.sans/' layer_*/*.qml
    sed -i 's/radius: vpx([34])/radius: vpx(Style.radius)/' layer_gameinfo/*.qml
    sed -i 's/? 1\.0 : 0\.3/? 1.0 : Style.dimmed/' layer_platform/PlatformCard.qml
    sed -i 's/opacity: 0\.4$/opacity: Style.missing/' layer_grid/GameGridItem.qml
    sed -i 's/opacity: 0\.25 }/opacity: Style.shade }/' layer_filter/FilterLayer.qml
    sed -i 's/opacity: 0\.85$/opacity: Style.panel/' layer_gameinfo/GamePreview.qml

    # Fail the build rather than ship a theme that half-took an edit, which
    # Pegasus would only report on the TV. Not `! grep`: set -e ignores a
    # negated command.
    if grep -rn 'globalFonts\|radius: vpx([0-9]\|opacity: 0\.[2348]\|: 0\.3$' layer_*; then
      exit 1
    fi

    sed -i 's/^name: .*/name: Pegasus Grid, Gruvbox Material/' theme.cfg
  '';

  # Pegasus writes these back when they're changed from its own menu. As
  # store links they can't be, so a change made on the TV lasts until Pegasus
  # restarts and the configuration stays what this file says.
  settings = pkgs.writeText "pegasus-settings.txt" ''
    general.theme: themes/gruvbox-material/
    general.fullscreen: true
    general.input-mouse-support: false
    general.verify-files: true
    general.scan-on-launch: true
    general.show-missing-games: false
    providers.es2.enabled: false
    providers.steam.enabled: false
    providers.gog.enabled: false
    providers.lutris.enabled: false
    providers.logiqx.enabled: false
    providers.skraper.enabled: false
  '';

  gameDirectories = pkgs.writeText "pegasus-game-dirs.txt"
    (lib.concatMapStrings (name: "${cfg.root}/roms/${name}\n") (lib.attrNames systems));

  headers = pkgs.linkFarm "arcade-collection-headers" (lib.mapAttrsToList
    (name: system: {
      inherit name;
      path = pkgs.writeText "${name}-header" ''
        collection: ${system.name}
        shortname: ${name}
        extensions: ${lib.concatStringsSep ", " system.extensions}
        launch: ${cfg.launch.${name}}
      '';
    })
    systems);

  collections = pkgs.writeShellApplication {
    name = "arcade-collections";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk ];
    text = ''
      for header in ${headers}/*; do
        system=$(basename "$header")
        file="${cfg.root}/roms/$system/metadata.pegasus.txt"

        games=
        if [[ -f $file ]]; then
          games=$(awk '/^game:/ { found = 1 } found' "$file")
        fi

        staging=$(mktemp "$file.XXXXXX")
        {
          cat "$header"
          if [[ -n $games ]]; then
            printf '\n%s\n' "$games"
          fi
        } > "$staging"

        chmod 664 "$staging"
        mv -f "$staging" "$file"
      done
    '';
  };

in
lib.mkIf cfg.enable {
  environment.systemPackages = [ pkgs.pegasus-frontend collections ];

  fonts.packages = [ pkgs.${fonts.sans.package} ];

  systemd.tmpfiles.rules = [
    "d ${home}/.config 0755 arcade arcade - -"
    "d ${configDirectory} 0755 arcade arcade - -"
    "d ${configDirectory}/themes 0755 arcade arcade - -"
    "L+ ${configDirectory}/themes/gruvbox-material - - - - ${theme}"
    "L+ ${configDirectory}/settings.txt - - - - ${settings}"
    "L+ ${configDirectory}/game_dirs.txt - - - - ${gameDirectories}"
  ];

  systemd.services.arcade-collections = {
    description = "Write the emulator station's collection headers";
    after = [ "systemd-tmpfiles-setup.service" ];
    before = [ "arcade-station.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Kept active so a switch that changes the headers runs it again.
      RemainAfterExit = true;
      User = "arcade";
      Group = "arcade";
      UMask = "0002";
      ExecStart = lib.getExe collections;
    };
  };
}
