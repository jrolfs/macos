{ config, lib, ... }:

let
  # Don't install casks specified in this environment variable. This is to
  # deal with applications managed by organization device management, etc.
  envApps = builtins.getEnv "NIX_MACOS_EXCLUDE_CASKS";
  excludeApps =
    if envApps != "" then
      let
        parsedApps = builtins.split "," envApps;
      in
      lib.trace ''


        ----------------------------------------
        ⚠︎ Excluding apps: ${toString parsedApps}
        ----------------------------------------
      '' parsedApps
    else
      [ ];

  # Pre-tap helpers — clone tap repos over HTTPS before the homebrew
  # module's activation runs `brew bundle` (which sanitizes the env
  # and drops SSH_AUTH_SOCK). We run git as root, whose gitconfig has
  # no url.*.insteadOf SSH rewrite. For private repos, the
  # HOMEBREW_GITHUB_API_TOKEN is read at eval time for HTTPS basic auth.
  githubToken = builtins.getEnv "HOMEBREW_GITHUB_API_TOKEN";
  githubAuth = if githubToken != "" then "${githubToken}@" else "";

  tapsDir = "${config.homebrew.brewPrefix}/../Library/Taps";

  tapDir = tap: let
    parts = lib.splitString "/" tap.name;
  in "${tapsDir}/${builtins.elemAt parts 0}/homebrew-${builtins.elemAt parts 1}";

  tapUrl = tap:
    if tap.clone_target != null then tap.clone_target
    else "https://${githubAuth}github.com/${builtins.elemAt (lib.splitString "/" tap.name) 0}/homebrew-${builtins.elemAt (lib.splitString "/" tap.name) 1}";

  primaryUser = config.system.primaryUser;

  preTapScript = lib.concatMapStringsSep "\n" (tap: ''
    if [ ! -d "${tapDir tap}" ]; then
      echo >&2 "Pre-tapping ${tap.name} (over HTTPS)..."
      git clone ${tapUrl tap} ${tapDir tap} \
        && chown -R ${primaryUser} ${tapDir tap} \
        || true
    fi
  '') config.homebrew.taps;
in

{
  homebrew.brewPrefix = "/opt/homebrew/bin";

  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "zap";
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

  # Pre-clone tap repos via HTTPS before the homebrew module runs
  # `brew bundle` (which sanitizes the env).
  system.activationScripts.homebrew.text = lib.mkBefore ''
    ${preTapScript}
  '';

  homebrew.global.brewfile = true;
  homebrew.global.lockfiles = true;

  homebrew.taps = [
    "jorgelbg/tap"
    "jrolfs/tap"
    "meterup/packages"
  ];

  homebrew.brews = [
    "mas"
    "openssl"

    { name = "meterup/packages/mcurl"; args = [ "HEAD" ]; }
    { name = "meterup/packages/mctl"; args = [ "HEAD" ]; }
  ];

  homebrew.masApps = lib.filterAttrs (name: _: !lib.elem name excludeApps) {
    "CARROT Weather" = 993487541;
    "Fantastical" = 975937182;
    "Flighty" = 1358823008;
    "Keystroke Pro" = 1572206224;
    # "Xcode" = 497799835;
  };

  homebrew.casks = builtins.filter (app: !lib.elem app excludeApps) [

    "1password"
    "1password-cli"
    "affinity"
    "arq"
    "charles"
    "cleanshot"
    "cursor"
    "daisydisk"
    "discord"
    "docker-desktop"
    "dropshare"
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
    "homebrew/cask/dash"
    "jrolfs/tap/lingon-pro"
    "jrolfs/tap/unite-pro"
    "karabiner-elements"
    "kitty"
    "linear-linear"
    "moom"
    "obsidian"
    "raycast"
    "resilio-sync"
    "safari-technology-preview"
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
