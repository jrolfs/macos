{ pkgs, lib, config, ... }:

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
# Velja has no iCloud sync (the binary links Defaults' iCloud support but the
# app is signed without the entitlement), and its only export covers rules and
# not settings, so the plist is the one place the whole configuration exists.
#
# Rules live in rules.toml rather than inline here, because they are data that
# wants to be captured out of the GUI rather than written by hand. The
# `velja-rules` CLI below moves them in both directions.

let
  domain = "com.sindresorhus.Velja";

  data = fromTOML (builtins.readFile ./rules.toml);

  # Velja decodes a rule into a struct rather than merging onto a default one,
  # so every field has to appear in the JSON even when it holds the boring
  # value. Keeping them here instead of in rules.toml is what lets a hand
  # written rule be three lines.
  ruleDefaults = {
    isEnabled = true;
    sourceApps = [ ];
    forceNewWindow = false;
    onlyFromAirdrop = false;
    openInBackground = false;
    runAfterBuiltinRules = false;
    isTransformScriptEnabled = false;
    transformScript = "";
    transformTestURL = "";
  };

  matcherDefaults = {
    fixture = "";
  };

  # Nix has no randomness, so an id that rules.toml does not carry is derived
  # from the text that identifies the rule. That is stable across machines and
  # across evaluations, where a freshly minted UUID would churn the declared
  # value on every switch. A captured rule keeps the id Velja gave it, so what
  # is declared here and what the GUI holds stay comparable.
  idFor = text:
    let
      digest = lib.toUpper (builtins.substring 0 32 (builtins.hashString "sha256" text));
      part = start: length: builtins.substring start length digest;
    in
    "${part 0 8}-${part 8 4}-${part 12 4}-${part 16 4}-${part 20 12}";

  normalizeMatcher = rule: matcher:
    matcherDefaults // { id = idFor "${rule.title}/${matcher.pattern}"; } // matcher;

  normalizeRule = rule:
    ruleDefaults
    // { id = idFor rule.title; }
    // rule
    // { matchers = map (normalizeMatcher rule) (rule.matchers or [ ]); };

  # Sindre's Defaults encodes a Codable value to JSON and stores the string, so
  # the plist holds an array of strings rather than an array of dicts.
  rules = map (rule: builtins.toJSON (normalizeRule rule)) (data.rules or [ ]);

  # `capture` has to undo what normalizeRule does, or every captured rule would
  # come back carrying Velja's whole struct. Handing jq the same attribute sets
  # the module normalizes with is what keeps the two directions from drifting.
  ruleDefaultsJSON = builtins.toJSON ruleDefaults;
  matcherDefaultsJSON = builtins.toJSON matcherDefaults;

  velja-rules = pkgs.writeShellApplication {
    name = "velja-rules";
    runtimeInputs = [ pkgs.jq pkgs.remarshal config.nix.package ];
    text = # bash
      ''
        domain=${lib.escapeShellArg domain}
        host=${lib.escapeShellArg config.networking.hostName}

        # The script edits the working tree, so it needs the checkout rather
        # than the store copy of itself. Same convention as cask-updater.
        config_dir="''${NIX_CONFIG_DIR:-$HOME/.config/system}"
        rules_file="$config_dir/modules/darwin/velja/rules.toml"

        # What Velja currently holds, decoded out of the JSON strings.
        #
        # Only the one key is pulled out, because the domain also carries
        # security-scoped bookmarks and plutil refuses to render <data> as
        # JSON: converting the whole domain fails outright. A machine that has
        # no rules yet has no key at all, which is not an error here.
        live_rules() {
          local staged raw
          staged=$(mktemp -t velja-live)
          defaults export "$domain" - > "$staged"
          raw=$(plutil -extract rules json -o - "$staged" 2>/dev/null || echo '[]')
          rm -f "$staged"
          jq '[.[] | fromjson]' <<<"$raw"
        }

        # What this flake says the whole Velja domain should be. Asking nix
        # rather than re-deriving it in shell means the defaults, the id
        # derivation and the JSON encoding have exactly one definition.
        declared_domain() {
          nix eval --json \
            "$config_dir#darwinConfigurations.$host.config.system.defaults.CustomUserPreferences.\"$domain\""
        }

        declared_rules() {
          declared_domain | jq '[.rules[]? | fromjson]'
        }

        capture_toml() {
          live_rules | jq \
            --argjson ruleDefaults ${lib.escapeShellArg ruleDefaultsJSON} \
            --argjson matcherDefaults ${lib.escapeShellArg matcherDefaultsJSON} '
              def strip($defaults):
                with_entries(select(.value != $defaults[.key]));
              { rules: [
                  .[]
                  | .matchers = [ .matchers[]? | strip($matcherDefaults) ]
                  | strip($ruleDefaults)
                ] }
            ' | json2toml
        }

        case "''${1:-}" in
          capture)
            if [[ "''${2:-}" == "--write" ]]; then
              # Everything above the first rule is prose worth keeping. Per
              # rule comments are not: they live between the tables that get
              # regenerated, and there is nowhere to put them back.
              staged=$(mktemp -t velja-rules)
              trap 'rm -f "$staged"' EXIT
              awk '/^\[\[/{exit} {print}' "$rules_file" > "$staged"
              capture_toml >> "$staged"
              mv "$staged" "$rules_file"
              trap - EXIT
              echo "wrote $rules_file"
            else
              capture_toml
            fi
            ;;

          apply)
            # import merges rather than replacing, so Velja keeps the keys it
            # owns (launch count, window frames) and only the declared ones
            # move. A whole dict also types booleans correctly, which a per
            # key plutil of a bare JSON scalar does not.
            staged=$(mktemp -t velja-domain)
            trap 'rm -f "$staged"' EXIT
            declared_domain | plutil -convert xml1 -o "$staged" -
            defaults import "$domain" "$staged"
            echo "applied the declared Velja domain for $host"
            ;;

          diff)
            if [[ "$(declared_rules | jq -S .)" == "$(live_rules | jq -S .)" ]]; then
              echo "rules.toml and Velja agree"
            else
              diff -u \
                <(declared_rules | jq -S .) \
                <(live_rules | jq -S .) \
                --label declared --label live || true
            fi
            ;;

          *)
            echo "usage: velja-rules {capture [--write]|apply|diff}" >&2
            exit 1
            ;;
        esac
      '';
  };
in
{
  environment.systemPackages = [ velja-rules ];

  system.defaults.CustomUserPreferences.${domain} = {
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

    inherit rules;

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
