{ pkgs, lib, hostname, userName, ... }:

# The account picture: the login window, the lock screen, Users & Groups, and
# the photo next to your name in Messages and Contacts.
#
# Not a preference. It is an attribute on the account's record in the local
# directory node, /var/db/dslocal/nodes/Default/users/<user>.plist, and three
# of them decide what gets drawn:
#
#   JPEGPhoto             the image bytes
#   Picture               a path, and what the picture chooser highlights
#   AvatarRepresentation  set in place of the other two when the picture is a
#                         Memoji, emoji or monogram, and preferred over them
#
# dslocal is per-machine and never leaves it, so this is the machine's picture
# rather than the Apple Account's, and writing it pushes nothing back up.
#
# What pushes the other way is com.apple.UserPictureSyncAgent, whose whole job
# is keeping the record and the Contacts "me" card showing the same thing. It
# is not a periodic sync. launchd starts it on
# com.apple.admin.userRecordChanged.userPicture, which is the notification the
# write below posts, and it answers by putting the me card's picture back. The
# first version of this module did exactly that to itself: the picture was set,
# the agent woke on the write, and JPEGPhoto went back to the Memoji while
# Picture stayed correct, which showed up as a login window that obeyed and a
# lock screen that did not. So the agent is disabled before the write rather
# than raced against, and the cost of that is the me card no longer tracking
# the account picture, which is the coupling this module exists to cut.
#
# It logs nothing at any level, so `log show` has no trace of it either way.
# What it does is legible in its own strings, and
# `notifyutil -p com.apple.admin.userRecordChanged.userPicture` starts it on
# demand if you want to watch it happen.
#
# There is no API for the picture either. nix-darwin has no option,
# `sysadminctl -picture` is accepted only while creating a user, and dscl
# writes strings rather than bytes. That leaves dsimport's `externalbinary:`
# prefix, which is missing from the man page and is what MDM has used for this
# for years.

let
  avatar = ../../avatars/${hostname}.png;

  # Copied out of the store rather than pointed at inside it: `Picture` would
  # be the only live reference to that store path, so a GC collecting this
  # generation would leave the record aimed at nothing. /Library/User Pictures
  # is where macOS keeps its own, at the same 512px these are.
  installed = "/Library/User Pictures/${userName}.png";

  apply = pkgs.writeShellScript "user-picture" ''
    set -uo pipefail

    # Ahead of the comparison, not inside the branch that writes: the picture
    # being already correct is no reason to leave the thing that undoes it
    # running.
    uid=$(id -u ${userName})
    if ! launchctl print-disabled "gui/$uid" 2>/dev/null \
      | grep -q '"com.apple.UserPictureSyncAgent" => disabled'; then
      echo "user picture: disabling com.apple.UserPictureSyncAgent" >&2
      launchctl disable "gui/$uid/com.apple.UserPictureSyncAgent" \
        || echo >&2 "user picture: could not disable the sync agent"
      launchctl bootout "gui/$uid/com.apple.UserPictureSyncAgent" 2>/dev/null || true
    fi

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

    # The header names the four delimiters, end of record, escape, field and
    # value, and then the two fields each line below it carries.
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
