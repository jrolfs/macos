{ config, lib, ... }:

let
  # Don't install casks specified in this environment variable. This is to
  # deal with applications managed by organization device management, etc.
  envApps = builtins.getEnv "NIX_MACOS_EXCLUDE_CASKS";
  excludeApps = if envApps != "" then
                  let
                    parsedApps = builtins.split "," envApps;
                  in
                  lib.trace ''


                  ----------------------------------------
                  ⚠︎ Excluding casks: ${toString parsedApps}
                  ----------------------------------------
                  '' parsedApps
                else [];
in

{
  homebrew.brewPrefix = "/opt/homebrew/bin";

  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "zap";
  homebrew.enable = true;

  homebrew.global.brewfile = true;
  homebrew.global.lockfiles = false;

  homebrew.taps = [
    "homebrew/bundle"

    "homebrew/cask-fonts"
    "homebrew/cask-versions"

     # Hover
     "codefresh-io/cli"
  ];

  # Example:
  # tap "hoverinc/tap", "git@github.com:hoverinc/homebrew-tap.git"
  homebrew.extraConfig = ''
  '';

  homebrew.brews = [
    "mackup"
    "mas"
    "openssl"

    "jakehilborn/jakehilborn/displayplacer"
  ];

  homebrew.masApps = {
    "CARROT Weather" = 993487541;
    "Fantastical" = 975937182;
    "Keystroke Pro" = 1572206224;
    "Pages" = 409201541;
    "Things" = 904280696;
    "Tweetbot" = 1384080005;
    # "Xcode" = 497799835;
  };

  homebrew.casks = builtins.filter (app: !lib.elem app excludeApps) [

    "1password"
    "1password-cli"
    "arq"
    "beeper"
    "blender"
    "charles"
    "cleanmymac"
    "cloudflare-warp"
    "daisydisk"
    "dash"
    "discord"
    "docker"
    "dropshare"
    "figma"
    "firefox"
    "firefox-developer-edition"
    "firefox-nightly"
    "google-chrome"
    "google-chrome-beta"
    "google-chrome-canary"
    "google-cloud-sdk"
    "grammarly"
    "grammarly-desktop"
    "insomnia"
    "jakehilborn/jakehilborn/displayplacer"
    "kaleidoscope"
    "karabiner-elements"
    "keka"
    "kitty"
    "lingon-x"
    "little-snitch"
    "moom"
    "nordvpn"
    "obsidian"
    "pop"
    "raycast"
    "resilio-sync"
    "safari-technology-preview"
    "skitch"
    "skype"
    "slack"
    "spotify"
    "stay"
    "sublime-merge"
    "superhuman"
    "tailscale"
    "tor-browser-alpha"
    "tuple"
    "visual-studio-code"
    "zed"
    "zed-preview"
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
