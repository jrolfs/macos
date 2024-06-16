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
                  ⚠︎ Excluding apps: ${toString parsedApps}
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

     "jorgelbg/tap"
  ];

  # Example:
  # tap "hoverinc/tap", "git@github.com:hoverinc/homebrew-tap.git"
  homebrew.extraConfig = ''
  '';

  homebrew.brews = [
    "mackup"
    "mas"
    "openssl"
  ];

  homebrew.masApps = lib.filterAttrs (name: _ : !lib.elem name excludeApps) {
    "CARROT Weather" = 993487541;
    "Fantastical" = 975937182;
    "Keystroke Pro" = 1572206224;
    "Pages" = 409201541;
    "Things" = 904280696;
    "Xcode" = 497799835;
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
    "grammarly-desktop"
    "hammerspoon"
    "insomnia"
    "karabiner-elements"
    "keka"
    "kitty"
    "lingon-x"
    "little-snitch"
    "moom"
    "obsidian"
    "pinentry-touchid"
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
    "tuple"
    "visual-studio-code"
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
