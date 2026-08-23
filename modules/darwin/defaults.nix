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

    universalaccess.closeViewScrollWheelToggle = true;

    ActivityMonitor.ShowCategory = 100;

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    loginwindow = {
      GuestEnabled = false;
      SHOWFULLNAME = false;
    };

    # Stage Manager stays off, and clicking the wallpaper must not shove every
    # window aside to reveal the desktop.
    WindowManager = {
      AutoHide = false;
      EnableStandardClickToShowDesktop = false;
      AppWindowGroupingBehavior = true;
      HideDesktop = true;
      StageManagerHideWidgets = false;
      StandardHideDesktopIcons = false;
      StandardHideWidgets = false;
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
}
