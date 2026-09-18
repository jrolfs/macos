{ config, lib, pkgs, ... }:

# Velja is a router rather than a browser: it takes every http(s) open, matches
# it against its per-app and per-host rules, and hands the URL to whichever
# real browser the rule names. None of that happens unless macOS opens links
# with Velja in the first place.

let
  bundleIdentifier = "com.sindresorhus.velja";
  app = "/Applications/Velja.app";

  user = lib.escapeShellArg config.system.primaryUser;

  # The handler table, not a normal preference key. Three entries make a
  # default browser: the two URL schemes, plus the web-browser role that
  # System Settings shows and that `open` resolves through.
  #
  # Written by merging rather than by declaring the array outright, which is
  # what system.defaults.CustomUserPreferences would do: a write replaces the
  # whole LSHandlers array, and the rest of it is handlers that apps put there
  # themselves when you accept their "make me the default" prompt (mailto →
  # Superhuman, slack, cleanshot, tg, rslsync). Those aren't declared anywhere
  # in this repo, so replacing the array would silently drop them.
  #
  # Removing this module does not restore Safari. Activation scripts only ever
  # run forwards; the entries stay until something else overwrites them.
  handlers = pkgs.writeText "default-browser.jq" ''
    def handler: {
      LSHandlerRoleAll: $identifier,
      LSHandlerPreferredVersions: { LSHandlerRoleAll: "-" }
    };

    .LSHandlers = (
      [
        .LSHandlers[]?
        | select(
            (.LSHandlerURLScheme // "") as $scheme
            | (.LSHandlerContentType // "") as $type
            | $scheme != "http"
              and $scheme != "https"
              and $type != "com.apple.default-app.web-browser"
          )
      ]
      + [
          handler + { LSHandlerURLScheme: "http" },
          handler + { LSHandlerURLScheme: "https" },
          handler + { LSHandlerContentType: "com.apple.default-app.web-browser" }
        ]
    )
  '';

  # The plist is edited directly because the API route no longer works from a
  # command line on macOS 26. LSSetDefaultHandlerForURLScheme, which is all
  # `defaultbrowser` and `duti` are, reports success for http/https and changes
  # nothing: LaunchServices only honours the request from a signed, bundled app
  # (which is how Superhuman's mailto entry got there).
  #
  # `defaults export | … | defaults import` rather than a write to the file:
  # cfprefsd owns the file and would flush its own cached copy over anything
  # written underneath it.
  #
  # jq's bundle identifier is lowercased because that is the case
  # LaunchServices itself writes, and the check below compares against what is
  # already in the table.
  setDefaultBrowser = pkgs.writeShellScript "set-default-browser" ''
    set -euo pipefail

    PATH=/usr/bin:/bin:/usr/sbin:/sbin

    domain="com.apple.LaunchServices/com.apple.launchservices.secure"
    jq=${lib.getExe' pkgs.jq "jq"}

    roles='[.LSHandlers[]?
      | select(.LSHandlerURLScheme == "http"
               or .LSHandlerURLScheme == "https"
               or .LSHandlerContentType == "com.apple.default-app.web-browser")
      | .LSHandlerRoleAll] | unique'

    current=$(defaults export "$domain" - | plutil -convert json -o - - | "$jq" -c "$roles")

    if [[ "$current" == '["${bundleIdentifier}"]' ]]; then
      exit 0
    fi

    echo "Setting default browser to ${bundleIdentifier}..."

    # Staged through a file rather than piped straight into `defaults import`:
    # import reads its stdin regardless of whether the transform upstream of it
    # succeeded, and empty stdin is something it complains about but still
    # exits 0 on, so a broken transform would look like a successful write and
    # take the whole handler table with it.
    table=$(mktemp -t default-browser)
    trap 'rm -f "$table"' EXIT

    defaults export "$domain" - \
      | plutil -convert json -o - - \
      | "$jq" --arg identifier "${bundleIdentifier}" -f ${handlers} \
      | plutil -convert xml1 -o "$table" -

    defaults import "$domain" "$table"

    # lsd caches the handler table, so until it restarts the write is invisible
    # to LSCopyDefaultHandlerForURLScheme and links keep going to the old
    # browser. launchd brings it straight back.
    killall lsd || true
  '';
in
{
  # Guarded on the app existing for the same reason the Dock's persistent-apps
  # are: with no handler installed for http/https and no Velja to open them,
  # links stop working altogether rather than falling back to Safari.
  #
  # postActivation runs after the mas and homebrew steps, so a first-time
  # install of Velja is already on disk by the time this looks for it.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [[ -d "${app}" ]]; then
      launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- ${setDefaultBrowser}
    else
      echo "Skipping default browser: ${app} not found"
    fi
  '';
}
