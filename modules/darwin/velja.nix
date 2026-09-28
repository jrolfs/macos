{ ... }:

# Velja's own configuration. default-browser.nix is the other half: it makes
# macOS hand Velja the links in the first place, and nothing here matters
# until it does.
#
# Everything Velja stores lives in a single plist inside its App Store sandbox
# container, under
# ~/Library/Containers/com.sindresorhus.Velja/Data/Library/Preferences. The
# container is not a reason to give up on declaring it. `defaults write` talks
# to cfprefsd, which resolves a sandboxed app's domain to its container for the
# owning user, so an ordinary CustomUserPreferences write arrives there just as
# it would for an unsandboxed app. What does not work is going at the file: the
# path is not stable API, and cfprefsd would flush its cached copy over
# anything written underneath it.
#
# These values were captured from the GUI rather than invented. Velja has no
# iCloud sync (the binary links Defaults' iCloud support but the app is signed
# without the entitlement), and its only export covers rules and not settings,
# so the plist is the one place the whole configuration exists.

let
  # Velja stores rules as Codable values that Sindre's Defaults encodes to JSON
  # and keeps as strings, so the plist holds an array of strings rather than an
  # array of dicts. toJSON reproduces that shape. Every field is written out,
  # including the ones left at their defaults, because Velja's decoder is
  # matching a struct rather than merging onto one.
  #
  # The ids are the ones Velja generated. Nix cannot invent a UUID, and keeping
  # the captured ones means this declaration and the GUI's own output stay
  # comparable, which is how the next rule gets captured.
  meterDashboard = {
    id = "AA70316F-1781-4342-96A8-D750D0BE7755";
    title = "Meter / Dashboard";
    isEnabled = true;
    openTarget = "browser:app.glide-browser.glide.developer";
    matchers = [
      {
        id = "F9D6BE8F-95F1-4ED6-896D-52759B0B7270";
        kind = "hostSuffix";
        pattern = "dashboard.meter.website";
        fixture = "https://dashboard.meter.website:8556/";
      }
    ];
    sourceApps = [ ];
    forceNewWindow = false;
    onlyFromAirdrop = false;
    openInBackground = false;
    runAfterBuiltinRules = false;
    isTransformScriptEnabled = false;
    transformScript = "";
    transformTestURL = "";
  };
in
{
  system.defaults.CustomUserPreferences."com.sindresorhus.Velja" = {
    # Where Velja sends a link that no rule claims. Unrelated to the system
    # default browser that default-browser.nix sets, which is Velja itself.
    defaultBrowser = "browser:app.glide-browser.glide";

    # The picker's running order, not a list of what is installed. Velja shows
    # the ones it finds, so naming a browser that is absent from a host costs
    # nothing and keeps both machines on one list.
    preferredBrowsers = [
      "browser:app.glide-browser.glide"
      "browser:app.glide-browser.glide.developer"
      "browser:com.apple.Safari"
      "browser:com.apple.SafariTechnologyPreview"
      "browser:org.mozilla.firefox"
      "browser:org.mozilla.firefoxdeveloperedition"
      "browser:org.mozilla.nightly"
      "browser:com.google.Chrome"
      "browser:com.google.Chrome.beta"
      "browser:com.google.Chrome.canary"
    ];

    menuBarIcon = "globe";

    rules = [ (builtins.toJSON meterDashboard) ];

    # Velja guards one-shot work behind these, and a machine that has never
    # launched it has none of them set. First launch would then run
    # setDefaultMenubarIcon over the icon chosen above, and run two rule format
    # migrations across rules that activation has already written in the format
    # they migrate to. Claiming the work is done keeps a first launch from
    # undoing the switch that installed the app.
    SS_App_runOnce__setDefaultMenubarIcon = true;
    SS_App_runOnce__migrate_ruleBrowserToOpenTarget = true;
    SS_App_runOnce__migrate_openTargetDefaultsToCanonicalRawValue = true;
  };
}
