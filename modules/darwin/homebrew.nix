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
  # Homebrew 4.7+ requires explicit confirmation for `brew bundle --cleanup`.
  homebrew.onActivation.extraFlags = [ "--force-cleanup" ];
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

  # Temporarily remove the HTTPS→SSH git URL rewrite during brew
  # activation — brew sanitizes SSH_AUTH_SOCK so gpg-agent SSH auth
  # is unavailable, but the global insteadOf rewrites all HTTPS clones
  # to SSH, causing formula fetches to fail.
  system.activationScripts.homebrew.text = lib.mkMerge [
    (lib.mkBefore ''
      sudo -u ${config.homebrew.user} git config --file ~${config.homebrew.user}/.config/git/config --unset-all url.git@github.com:.insteadOf 2>/dev/null || true
    '')
    (lib.mkAfter ''
      sudo -u ${config.homebrew.user} git config --file ~${config.homebrew.user}/.config/git/config url.git@github.com:.insteadOf https://github.com/
    '')
  ];

  homebrew.global.brewfile = true;

  homebrew.taps = [
    { name = "jorgelbg/tap"; trusted = true; }
    { name = "jrolfs/tap"; trusted = true; }
    {
      # meterup/homebrew-packages is private, and brew taps over HTTPS with
      # GIT_TERMINAL_PROMPT=0 — so on a machine with no cached GitHub
      # credential the clone dies with "could not read Username". (It works on
      # a long-lived machine only because a credential is sitting in the
      # keychain, which is not reproducible.) Note the activation script below
      # deliberately unsets the global HTTPS→SSH `insteadOf` rewrite, so that
      # can't rescue it either.
      #
      # clone_target pins this tap to SSH, which authenticates with the
      # bootstrap-minted ~/.ssh/id_ed25519. That key is passphraseless, so it
      # needs no agent — which is exactly why brew sanitizing SSH_AUTH_SOCK
      # (the reason the insteadOf workaround exists) doesn't break it.
      name = "meterup/packages";
      clone_target = "git@github.com:meterup/homebrew-packages.git";
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
    "CARROT Weather" = 993487541;
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
    "font-fira-code-nerd-font"
    "font-hack-nerd-font"
    "font-ibm-plex"
    "font-iosevka"
    "font-iosevka-slab"
    "font-jetbrains-mono"
    "font-jetbrains-mono-nerd-font"
  ];
}
