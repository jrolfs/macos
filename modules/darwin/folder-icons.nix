{ pkgs, lib, config, userName, ... }:

# Custom icons on folders in $HOME.
#
# Separate from icons.nix, which handles /Applications, because folders use a
# different mechanism and a much easier one. An app bundle needs a full .icns
# written into an Icon\r resource fork, and getting at one means fighting
# com.apple.macl and Full Disk Access. A folder only needs a glyph named in a
# small extended attribute, which macOS 26 composites onto its own folder
# artwork, so it stays correct in light and dark mode, at every icon size,
# without this repo carrying any image assets. See pkgs/folder-icon.rs for the
# format and how it was recovered.
#
# The problem this exists to solve is Resilio Sync. It writes a 1.2 MB Icon\r
# into every share it creates, which puts a blue sync badge on Configuration,
# Images, Sync and Documents and makes them the only folders in $HOME that
# don't look like folders. The customisation xattr takes precedence over that
# Icon\r, and folder-icon deletes it as well.
#
# Resilio syncs file contents, not extended attributes, so the xattr is
# machine-local and every machine has to be told again. That is the whole
# reason this is declared here rather than clicked once in Finder.
#
# Two things the popover does that this module does not. It can tint the folder
# body, which is stored as an ordinary Finder tag and so would also put the
# folder under that colour in the sidebar; that's a tagging decision, not an
# icon one. And it can set a bespoke image, which is the classic Icon\r path
# that icons.nix already has a tool for.

let
  folderIcons = config.local.finder.folderIcons;
  home = "/Users/${userName}";

  tool = pkgs.rustTool {
    name = "folder-icon";
    src = ./pkgs/folder-icon.rs;
    libraries = [
      (pkgs.rustLibrary {
        name = "custom-icon";
        src = ./pkgs/custom-icon.rs;
      })
    ];
  };

  # `folder-icon show` prints the stored JSON plus the two bits of state that
  # have to agree with it, so the reconcile can skip a folder on a string
  # compare instead of re-writing every switch and churning Finder's icon
  # cache.
  expected = { kind, value, ... }:
    let key = if kind == "symbol" then "sym" else "emoji";
    in "{\"${key}\":\"${value}\"} flag=1 legacy=0";

  reconcile = pkgs.writeShellScript "folder-icons" ''
    set -uo pipefail

    tool=${tool}/bin/folder-icon

    # A share that hasn't synced yet, or a folder that only exists on another
    # host, is not an error: it just isn't here to decorate.
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList
      (path: icon: ''
        if [ -d ${lib.escapeShellArg path} ]; then
          current=$("$tool" show ${lib.escapeShellArg path} 2>/dev/null || true)
          if [ "$current" != ${lib.escapeShellArg (expected icon)} ]; then
            echo "folder-icons: ${path} -> ${icon.kind} ${icon.value}"
            "$tool" set ${lib.escapeShellArg path} ${icon.kind} ${lib.escapeShellArg icon.value} \
              || echo >&2 "folder-icons: could not set ${path}"
          fi
        fi
      '')
      folderIcons)}
  '';
in
{
  options.local.finder.folderIcons = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options = {
        symbol = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "gearshape.2";
          description = ''
            An SF Symbol name, drawn embossed into the folder body in the
            folder's own colour. Any name from the SF Symbols app works.
            Mutually exclusive with `emoji`.
          '';
        };

        emoji = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "🚲";
          description = ''
            An emoji, drawn in full colour on the folder body. Mutually
            exclusive with `symbol`.
          '';
        };

        kind = lib.mkOption {
          type = lib.types.enum [ "symbol" "emoji" ];
          internal = true;
          readOnly = true;
          default = if config.symbol != null then "symbol" else "emoji";
        };

        value = lib.mkOption {
          type = lib.types.str;
          internal = true;
          readOnly = true;
          # Falls back to "" rather than null when neither is set, so the
          # assertion below is what gets reported instead of a type error from
          # this option being evaluated first.
          default =
            if config.symbol != null then config.symbol
            else if config.emoji != null then config.emoji
            else "";
        };
      };
    }));
    default = { };
    example = lib.literalExpression ''
      {
        "/Users/jamie/Configuration" = { symbol = "gearshape.2"; };
        "/Users/jamie/Sync" = { emoji = "🔄"; };
      }
    '';
    description = ''
      Folder icons, keyed by absolute path. Each folder gets either an SF
      Symbol or an emoji composited onto the system folder artwork, replacing
      any Icon\r resource fork already there.
    '';
  };

  config = {
    assertions = lib.mapAttrsToList
      (path: icon: {
        assertion = (icon.symbol == null) != (icon.emoji == null);
        message =
          "local.finder.folderIcons.\"${path}\" needs exactly one of `symbol` or `emoji`.";
      })
      folderIcons;

    local.finder.folderIcons = lib.mkDefault {
      # The four Resilio shares, which are the ones that arrive with an icon
      # of their own. Symbols rather than emoji: these sit next to the stock
      # Desktop/Developer/Movies folders, which are all embossed glyphs.
      "${home}/Configuration" = { symbol = "gearshape.2"; };
      "${home}/Documents" = { symbol = "doc.text"; };
      "${home}/Images" = { symbol = "photo.stack"; };
      "${home}/Sync" = { symbol = "arrow.triangle.2.circlepath"; };
    };

    environment.systemPackages = [ tool ];

    # As the user, not root: these are the user's own folders, and Documents is
    # TCC-protected, so the write wants to come from the session that has the
    # grant rather than from root.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "folder icons..." >&2
      sudo --user=${userName} -- ${reconcile} || \
        echo >&2 "folder-icons: reconcile failed"
    '';
  };
}
