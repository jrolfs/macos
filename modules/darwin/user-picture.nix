{ pkgs, lib, hostname, userName, ... }:

# The account picture — the login window, Users & Groups, and the photo next to
# your name in Messages and Contacts.
#
# Not a preference. It is an attribute on the account's record in the local
# directory node, /var/db/dslocal/nodes/Default/users/<user>.plist, and three
# of them decide what gets drawn:
#
#   JPEGPhoto             the image bytes, and what the UI actually renders
#   Picture               a path, and what the picture chooser highlights
#   AvatarRepresentation  set in place of the other two when the picture is a
#                         Memoji, emoji or monogram, and preferred over them
#
# dslocal is per-machine and never leaves it, which is the point: the picture
# is the machine's rather than the Apple Account's, and setting it here pushes
# nothing back up. The coupling only runs the other way. macOS seeds JPEGPhoto
# from the Apple Account photo at sign-in and can push it over the top again
# when that photo changes, and there is no preference to stop it — so this runs
# on every switch rather than once, and a clobbered picture lasts until the
# next darwin-rebuild instead of forever.
#
# There is no API for it. nix-darwin has no option, `sysadminctl -picture` is
# accepted only while creating a user, and dscl writes strings rather than
# bytes. That leaves dsimport's `externalbinary:` prefix, which is missing from
# the man page and is what MDM has used for this for years.

let
  avatar = ../../avatars/${hostname}.png;

  # Copied out of the store rather than pointed at inside it: `Picture` would
  # be the only live reference to that store path, so a GC collecting this
  # generation would leave the record aimed at nothing. /Library/User Pictures
  # is where macOS keeps its own, at the same 512px these are.
  installed = "/Library/User Pictures/${userName}.png";

  apply = pkgs.writeShellScript "user-picture" ''
    set -uo pipefail

    current=$(mktemp)
    manifest=$(mktemp)
    trap 'rm -f "$current" "$manifest"' EXIT

    # dscl renders a binary attribute as hex beneath a label line, so dropping
    # that line and the whitespace gives the bytes back. A record carrying no
    # photo prints nothing, which compares unequal and applies, as it should.
    dscl . -read /Users/${userName} JPEGPhoto 2>/dev/null \
      | tail -n +2 | tr -d ' \n' | xxd -r -p > "$current"

    if cmp -s "$current" ${avatar}; then
      exit 0
    fi

    echo "user picture: ${hostname}" >&2

    install -m 644 ${avatar} ${lib.escapeShellArg installed}

    # Left in place, a Memoji outranks the photo and nothing visible changes.
    dscl . -delete /Users/${userName} AvatarRepresentation 2>/dev/null || true

    # The header names the four delimiters — end of record, escape, field,
    # value — and then the two fields each line below it carries.
    printf '%s\n%s\n' \
      '0x0A 0x5C 0x3A 0x2C dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto' \
      ${lib.escapeShellArg "${userName}:${installed}"} \
      > "$manifest"

    dsimport "$manifest" /Local/Default M

    # Retires the stock path the record was handed when the account was made.
    dscl . -create /Users/${userName} Picture ${lib.escapeShellArg installed}
  '';
in
{
  # Guarded so that adding a host before its avatar is a host without a
  # picture rather than a configuration that won't evaluate.
  system.activationScripts.postActivation.text = lib.mkAfter (
    lib.optionalString (builtins.pathExists avatar) # bash
      ''
        ${apply} || echo >&2 "user picture: could not set the account picture"
      ''
  );
}
