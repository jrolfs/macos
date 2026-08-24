{ config, lib, hostname, ... }:

{
  system.defaults = {
    dock = {
      autohide = true;
      launchanim = true;
      mineffect = "scale";
      minimize-to-application = true;
      mru-spaces = false;
      orientation = "bottom";
      show-process-indicators = true;
      show-recents = false;
      showhidden = true;
      static-only = false;
      tilesize = 48;

      showAppExposeGestureEnabled = true;
      showMissionControlGestureEnabled = true;

      # 1 is the "no action" sentinel, not a real action id — this turns off the
      # Quick Note corner, which otherwise fires whenever the pointer lands in
      # the bottom-right on the way to something else.
      "wvous-br-corner" = 1;

      # Every entry has to exist at activation time or the Dock renders a "?"
      # placeholder tile in its place, so anything listed here needs to be
      # installed unconditionally — not excluded via NIX_MACOS_EXCLUDE_CASKS.
      persistent-apps = [
        "/Applications/kitty.app"
        "/Applications/Zed.app"
        "/Applications/Linear.app"
        "/Applications/Obsidian.app"
        "/Applications/Glide.app"
        "/Applications/Glide Developer.app"
        "/Applications/Superhuman.app"
        "/Applications/Telegram.app"
        "/System/Applications/Messages.app"
        "/Applications/WhatsApp.app"
        "/Applications/Slack.app"
        "/Applications/Fantastical.app"
      ];

      persistent-others = [
        "/Users/${config.system.primaryUser}/Images/Screenshots"
        {
          folder = {
            path = "/Users/${config.system.primaryUser}/Downloads";
            arrangement = "date-added";
            showas = "fan";
          };
        }
      ];
    };

    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      QuitMenuItem = true;

      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv";
      NewWindowTarget = "Home";
      ShowPathbar = true;

      # What the desktop is allowed to hold. The internal disk is reachable
      # from anywhere and only ever in the way; anything plugged in or mounted
      # is worth an icon precisely because it is temporary.
      CreateDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowMountedServersOnDesktop = false;
    };

    # The desktop's own view options — Finder's View → Show View Options when
    # the desktop has focus. nix-darwin has no structured option for it because
    # it isn't a flat key: it's one nested dictionary per view style, and a
    # write replaces the whole thing rather than merging into it, so every key
    # Finder expects has to be here (which is why the untouched defaults are
    # spelled out alongside the two settings that aren't).
    #
    # Finder reads this rather than owning it, so the write sticks — but it
    # picks the value up when it next launches, not while it is running. On a
    # fresh machine that means the first login; on a running one, `killall
    # Finder`.
    CustomUserPreferences."com.apple.finder".DesktopViewSettings = {
      GroupBy = "None";

      IconViewSettings = {
        arrangeBy = "dateCreated";
        iconSize = 96.0;
        gridSpacing = 100.0;

        backgroundType = 0;
        backgroundColorRed = 1.0;
        backgroundColorGreen = 1.0;
        backgroundColorBlue = 1.0;
        gridOffsetX = 0.0;
        gridOffsetY = 0.0;
        labelOnBottom = true;
        showIconPreview = true;
        showItemInfo = false;
        textSize = 12.0;
        viewOptionsVersion = 1;
      };
    };

    screencapture.location = "~/Images/Screenshots";

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;

      # Three-finger vertical swipe has to stay off for three-finger drag to
      # work — they compete for the same gesture.
      TrackpadThreeFingerVertSwipeGesture = 0;
    };

    LaunchServices = {
      LSQuarantine = false;
    };

    # Karabiner maps Fn+HJKL to the arrow keys, so macOS must not claim the Fn
    # key for itself. Requires a restart to take effect.
    hitoolbox.AppleFnUsageType = "Do Nothing";

    menuExtraClock = {
      ShowAMPM = false;
      ShowDate = 2;
      ShowDayOfWeek = false;
    };

    # "Displays have separate Spaces" off: one space spans every display, so a
    # fullscreen window doesn't blank the other monitor.
    spaces.spans-displays = true;

    # universalaccess is deliberately absent. com.apple.universalaccess is
    # TCC-protected, and activation writes it via `launchctl asuser … sudo
    # --user=jamie -- defaults write`, which detaches the write from any process
    # holding Full Disk Access — so it fails with "Could not write domain"
    # regardless of what the terminal is granted. activate runs under `set -e`,
    # so that one failure aborted every remaining step: the rest of the user
    # defaults, the Dock restart, launchd services, the Homebrew bundle and the
    # home-manager activation. Zoom's scroll-gesture toggle is a one-time click
    # in System Settings → Accessibility → Zoom; it is not worth an FDA-granted
    # wrapper binary, which is the only thing that would make the write land.

    # screensaver is deliberately absent too. The picture and the screen saver
    # are two halves of one store now — Desktop and Idle under the same scope in
    # com.apple.wallpaper — and WallpaperAgent owns it, so the module choice
    # (Drift, here) is no more declarable than the wallpaper was; see
    # modules/home/wallpaper.nix, which reaches the wallpaper half through
    # NSWorkspace because that is the only public way in. The legacy
    # com.apple.screensaver keys still exist and are still populated, but they
    # are a mirror the store writes to rather than the thing being read, and
    # they are ByHost, which CustomUserPreferences writes past for the same
    # reason it can't reach the menu bar items below. nix-darwin's two options
    # here (askForPassword, askForPasswordDelay) are about the lock screen, not
    # about which saver runs, and are left at their defaults. Hammerspoon is no
    # help either, which is where the wallpaper half went: hs.caffeinate can
    # start a screen saver and nothing more — there is no API for choosing one
    # or for the idle time before it runs.

    ActivityMonitor.ShowCategory = 100;

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    loginwindow = {
      GuestEnabled = false;
      SHOWFULLNAME = false;
    };

    # Stage Manager stays off, and clicking the wallpaper must not shove every
    # window aside to reveal the desktop.
    #
    # The two HideWidgets options are the whole of System Settings → Desktop &
    # Dock → Widgets → "Show widgets", and turning them on is what gets rid of
    # the clock and calendar macOS seeds a new desktop with. It is all or
    # nothing: which widgets are on the desktop, and where, is held in
    # com.apple.chronod's own store, so there is no declaring a subset.
    WindowManager = {
      AutoHide = false;
      EnableStandardClickToShowDesktop = false;
      AppWindowGroupingBehavior = true;
      HideDesktop = true;
      StageManagerHideWidgets = true;
      StandardHideDesktopIcons = false;
      StandardHideWidgets = true;
    };

    # Only the menu bar items whose visibility nix-darwin can express: the
    # option is a bool that writes 18 (shown) or 24 (hidden), so the "show when
    # active" states (Bluetooth = 8, Display = 2 on newt) have no representation
    # here. They also live in a ByHost domain, which CustomUserPreferences
    # writes past, so there is no workaround short of a bespoke activation
    # script.
    controlcenter.Sound = true;

    smb = {
      NetBIOSName = lib.toUpper hostname;
      ServerDescription = config.networking.computerName;
    };

    ".GlobalPreferences"."com.apple.sound.beep.sound" =
      "/System/Library/Sounds/Tink.aiff";

    NSGlobalDomain = {
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.springing.delay" = 0.0;
      "com.apple.springing.enabled" = true;
      "com.apple.swipescrolldirection" = true;
      "com.apple.trackpad.enableSecondaryClick" = true;
      "com.apple.trackpad.trackpadCornerClickBehavior" = 1;
      AppleFontSmoothing = 0;
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "WhenScrolling";
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = true;
      NSDisableAutomaticTermination = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSScrollAnimationEnabled = true;
      NSTableViewDefaultSizeMode = 2;
      NSTextShowsControlCharacters = false;
      NSUseAnimatedFocusRing = true;
      NSWindowResizeTime = 0.01;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;

      AppleICUForce24HourTime = true;
      AppleInterfaceStyle = "Dark";
      AppleWindowTabbingMode = "always";
      "com.apple.keyboard.fnState" = true;
    };
  };

  # Remote Login. Enabled declaratively rather than left to whoever last
  # visited System Settings — provisioning a new machine needs it before there
  # is anyone at the keyboard to turn it on.
  services.openssh.enable = true;

  # On by default on newt, off on a fresh install — a default that points the
  # wrong way is worth pinning even when the value looks unremarkable.
  networking.applicationFirewall = {
    enable = true;
    allowSigned = true;
    allowSignedApp = true;
    enableStealthMode = false;
  };

  time.timeZone = "America/Los_Angeles";

  system.startup.chime = false;

  # systemsetup writes these to both power sources at once, so only the values
  # newt uses for both can move over. Its computer-sleep setting differs by
  # source — never on AC, but not on battery — which this cannot express, so it
  # stays out rather than getting flattened into a laptop that never sleeps.
  power.sleep = {
    display = 45;
    harddisk = 10;
  };
}
