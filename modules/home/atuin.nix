{ pkgs, lib, config, ... }:

# Logs atuin into the sync server on a machine that hasn't yet. The login
# material lives in one 1Password item — op://Secrets/Atuin, recorded as
# `atuin-key` in the bootstrap repo's secrets.json — with username/password for
# the account and a `key` field holding the encryption key (`atuin key` output).
#
# The key goes in on stdin rather than argv: with --username/--password given
# and --key absent, `atuin login` reads the encryption key as a single line
# from stdin (both the legacy and hub login paths), so it never shows up in a
# process listing. Non-interactively a wrong key is a logout-and-fail, not a
# retry prompt, so a bad value can't wedge the switch.
#
# op is the Homebrew CLI (1password-cli cask) at its absolute path, not
# pkgs._1password-cli: desktop-app integration (Touch ID authorization) is
# granted to that binary. On the first run op pops an authorization prompt —
# the timeouts are generous enough to reach for it, and a switch run with
# 1Password locked or signed out degrades to a warning. Linux hosts will want
# a service account scoped to the Secrets vault instead; this module is only
# imported on Darwin.

let
  item = "op://Secrets/Atuin";
  dataDirectory = "${config.home.homeDirectory}/.local/share/atuin";

  login = pkgs.writeShellScript "atuin-login" ''
    set -uo pipefail

    export PATH=${lib.makeBinPath [ pkgs.atuin pkgs.coreutils ]}:$PATH

    # The session file is what a successful login writes and what logout
    # deletes, so its presence is "logged in" and a logout re-runs this on the
    # next switch.
    [ -e ${lib.escapeShellArg dataDirectory}/session ] && exit 0

    op() { timeout 120 /opt/homebrew/bin/op --account rolfers.1password.com "$@"; }

    username=$(op read '${item}/username') || exit 1
    password=$(op read '${item}/password') || exit 1
    key=$(op read '${item}/key') || exit 1

    printf '%s\n' "$key" | timeout 120 atuin login --username "$username" --password "$password"
  '';
in
{
  home.activation.atuinLogin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${login} \
      || warnEcho "atuin: not logged in — unlock 1Password and rerun, or run 'atuin login' by hand"
  '';
}
