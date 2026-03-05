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

  homebrew.global.brewfile = true;
  homebrew.global.lockfiles = true;

  homebrew.taps = [
    "jorgelbg/tap"
  ];

  # Example:
  # tap "hoverinc/tap", "git@github.com:hoverinc/homebrew-tap.git"
  homebrew.extraConfig = ''
    tap "meterup/packages", "git@github.com:meterup/packages"
  '';

  homebrew.brews = [
    "mas"
    "openssl"
  ];

  homebrew.masApps = lib.filterAttrs (name: _: !lib.elem name excludeApps) {
    "CARROT Weather" = 993487541;
    "Fantastical" = 975937182;
    "Flighty" = 1358823008;
    "Keystroke Pro" = 1572206224;
    # "Xcode" = 497799835;
  };

  homebrew.casks = builtins.filter (app: !lib.elem app excludeApps) [

    "meterup/packages/mcurl"
    "meterup/packages/mctl"

    "1password"
    "1password-cli"
    "arq"
    "charles"
    "cloudflare-warp"
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
    "karabiner-elements"
    "kitty"
    "lingon-x"
    "little-snitch"
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
    "tuple"
    # "unite"
    "visual-studio-code"
    "whatsapp"
    "yaak"
    "zed"
    "zoom"

    # Fonts
    "font-ibm-plex"
    "font-iosevka"
    "font-iosevka-slab"
    "font-fira-code-nerd-font"
    "font-jetbrains-mono"
    "font-jetbrains-mono-nerd-font"
  ];
}
