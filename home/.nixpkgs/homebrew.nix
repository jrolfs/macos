{ config, lib, ... }:

{
  homebrew.brewPrefix = "/opt/homebrew/bin";

  homebrew.autoUpdate = true;
  homebrew.cleanup = "zap";
  homebrew.enable = true;

  homebrew.global.brewfile = true;
  homebrew.global.noLock = true;

  homebrew.taps = [
    "homebrew/bundle"
    "homebrew/core"

    "homebrew/cask"
    "homebrew/cask-fonts"
    "homebrew/cask-versions"

     # Hover
     "codefresh-io/cli"
  ];

  homebrew.extraConfig = ''
    # Hover
    tap "hoverinc/tap", "git@github.com:hoverinc/homebrew-tap.git"
    brew "hoverinc/tap/hoverctl"
  '';

  homebrew.brews = [
    "mackup"
    "mas"
    "openssl"
  ];

  homebrew.masApps = {
    "CARROT Weather" = 993487541;
    "Fantastical" = 975937182;
    "Pages" = 409201541;
    "Things" = 904280696;
    "Tweetbot" = 1384080005;
    "Xcode" = 497799835;
  };

  homebrew.casks = [
    "1password"
    "1password-cli"
    "alfred"
    "arq"
    "charles"
    "cleanmymac"
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
    "google-chrome-canary"
    "grammarly"
    "hocus-focus"
    "insomnia"
    "kaleidoscope"
    "karabiner-elements"
    "keka"
    "kitty"
    "lingon-x"
    "little-snitch"
    "moom"
    "nordvpn"
    "pop"
    "resilio-sync"
    "safari-technology-preview"
    "skitch"
    "skype"
    "slack"
    "spotify"
    "stay"
    "sublime-merge"
    "superhuman"
    "tor-browser-alpha"
    "tuple"
    "visual-studio-code"

    # Fonts
    "font-ibm-plex"
    "font-fira-code-nerd-font"
  ];
}
