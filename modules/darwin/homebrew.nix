{ config, lib, hostname, ... }:

let
  # Per-host cask/masApps exclusions — typically apps installed by
  # organization device management. Keyed on the short hostname.
  excludeByHost = {
    # Xcode is a many-GB mas install; skip it during provisioning and add it
    # by hand (or drop this entry) when it's actually needed.
    ala = [ "Xcode" ];
    newt = [ "Xcode" "zoom" ];
    orolo = [ "google-chrome" "Xcode" "zoom" ];
    yours-truly = [ "Xcode" ];
  };
  excludeApps = excludeByHost.${hostname} or [ ];

in

{
  homebrew.prefix = "/opt/homebrew";

  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "zap";
  # nix-darwin defaults this false (so repeated switches are idempotent), which
  # passes `--no-upgrade` to `brew bundle` — meaning an already-installed cask is
  # never upgraded. That silently breaks the self-managed jrolfs/tap casks: bump
  # the pinned version + sha256 in the .rb, re-switch, and nothing happens.
  #
  # Trade-off accepted here: switches are no longer version-idempotent, since
  # every managed cask (Firefox, Chrome, …) may also upgrade on any switch. The
  # narrower alternative is to leave this false and upgrade the two self-managed
  # casks explicitly — see the note in tap.nix.
  homebrew.onActivation.upgrade = true;
  # No --force-cleanup in extraFlags: nix-darwin passes it itself now (for
  # Homebrew 4.7+), so setting it here produced `--force-cleanup
  # --force-cleanup`. It was needed against the older pinned nix-darwin.
  homebrew.enable = true;

  # Clear immutable flags from any applications managed by
  # self-service tools so Homebrew can manage all applications.
  system.activationScripts.extraActivation.text = lib.mkIf config.homebrew.enable (
    lib.mkAfter ''
      if [ -d /Applications ]; then
        chflags -R noschg,nouchg /Applications 2>/dev/null || true
      fi
    ''
  );

  homebrew.global.brewfile = true;

  # `brew bundle` runs during activation *before* home-manager links
  # ~/.config/git/config, so on a first switch git has no credential helper and
  # no URL rewrites. The private meterup tap and the `--HEAD` brews below (which
  # build from https://github.com/meterup/api.git) then die under Homebrew's
  # GIT_TERMINAL_PROMPT=0 with "could not read Username".
  #
  # /etc/gitconfig is the only git config in place that early, and it is read by
  # the git Homebrew actually shells out to (`brew --config` reports the Command
  # Line Tools git, not the nix one, whose system config lives inside its store
  # path). nix-darwin writes /etc at activation line ~2318; brew bundle runs at
  # ~2855.
  #
  # `store` reads ~/.git-credentials, which `bootstrap` materializes from
  # 1Password before the first switch. SSH is not usable here: keys minted by
  # bootstrap's OAuth App are barred from organization resources, so a fresh
  # machine's key can read personal private repos but not meterup's.
  #
  # The second rule looks like a no-op but isn't. Once home-manager has run, the
  # user config rewrites all of https://github.com/ to SSH; git resolves
  # insteadOf by *longest* matching prefix, so this pins meterup to HTTPS and
  # keeps the token path working on later switches.
  environment.etc."gitconfig".text = ''
    [credential "https://github.com"]
    	helper = store

    [url "https://github.com/meterup/"]
    	insteadOf = https://github.com/meterup/
  '';

  homebrew.taps = [
    { name = "jorgelbg/tap"; trusted = true; }
    { name = "jrolfs/tap"; trusted = true; }
    {
      # Private, so the clone needs a credential. It comes over HTTPS from
      # ~/.git-credentials via the helper configured above, rather than over
      # SSH with a clone_target: brew sanitizes SSH_AUTH_SOCK during
      # activation, and the on-disk key bootstrap mints can't reach org repos
      # anyway.
      name = "meterup/packages";
      trusted = true;
    }
  ];

  homebrew.brews = [
    "mas"
    "openssl"

    { name = "meterup/packages/mcurl"; args = [ "HEAD" ]; }
    { name = "meterup/packages/mctl"; args = [ "HEAD" ]; }
    { name = "meterup/packages/hostsfile"; args = [ "HEAD" ]; }
  ];

  homebrew.masApps = lib.filterAttrs (name: _: !lib.elem name excludeApps) {
    "Cloud Baby Monitor" = 517602535;
    "Fantastical" = 975937182;
    "Flighty" = 1358823008;
    "Velja" = 1607635845;
    "Xcode" = 497799835;
  };

  homebrew.casks = builtins.filter (app: !lib.elem app excludeApps) [

    "1password"
    "1password-cli"
    "affinity"
    "arq"
    "aws-vpn-client"
    "claude"
    "cleanshot"
    "cursor"
    "daisydisk"
    "discord"
    "fantastical"
    "figma"
    "firefox"
    "firefox@developer-edition"
    "firefox@nightly"
    "glide-browser"
    "google-chrome"
    "google-chrome@beta"
    "google-chrome@canary"
    "grammarly-desktop"
    "hammerspoon"
    "jrolfs/tap/lingon-pro"
    "jrolfs/tap/unite-pro"
    "karabiner-elements"
    "kitty"
    "linear"
    "loom"
    "maxon"
    "moom"
    "obsidian"
    "orbstack"
    "plex"
    "plexamp"
    "proxyman"
    "raycast"
    "resilio-sync"
    "safari-technology-preview"
    "sensei"
    "signal"
    "slack"
    "spotify"
    "stay"
    "superhuman"
    "tailscale-app"
    "telegram"
    "whatsapp"
    "yaak"
    "zed"
    "zed@preview"
    "zoom"

    # Fonts
    "font-atkinson-hyperlegible"
    "font-fira-code-nerd-font"
    "font-geist"
    "font-hack-nerd-font"
    "font-ibm-plex"
    "font-inter"
    "font-iosevka"
    "font-iosevka-slab"
    "font-jetbrains-mono"
    "font-jetbrains-mono-nerd-font"
    "font-public-sans"
  ];
}
