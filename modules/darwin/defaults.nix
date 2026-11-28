{ user, ... }:

# macOS 설정 앱에서 고르는 값들. 타입 있는 nix-darwin 옵션이 없는 것은 CustomUserPreferences 로 쓴다.
{
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Always";

      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2; # Values: 120, 90, 60, 30, 12, 6, 2
      InitialKeyRepeat = 15; # Values: 120, 94, 68, 35, 25, 15
      AppleKeyboardUIMode = 3;   # full keyboard access (Tab through all controls)

      # Disable "smart"/auto text substitutions (annoying when coding)
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;

      NSNavPanelExpandedStateForSaveMode = true;
      PMPrintingExpandedStateForPrint = true;

      NSDocumentSaveNewDocumentsToCloud = false;

      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.sound.beep.volume" = 0.0;
      "com.apple.sound.beep.feedback" = 0;
    };

    dock = {
      autohide = true;
      # Stock values are 0.5/1.0 seconds, which feel sluggish next to a tiling WM.
      autohide-delay = 0.0;
      autohide-time-modifier = 0.2;
      show-recents = false;
      launchanim = true;
      # Bottom, not right: rift-grid's scrolling layout moves columns in and out at the side edges.
      orientation = "bottom";
      tilesize = 48;
      mru-spaces = false;           # don't reorder Spaces by recent use
      minimize-to-application = true;
      show-process-indicators = true;
      # Hot corners disabled (1 = no action)
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;            # show hidden files
      _FXShowPosixPathInTitle = false;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";       # list view
      FXDefaultSearchScope = "SCcf";       # search the current folder by default
      _FXSortFoldersFirst = true;
      QuitMenuItem = true;                 # allow Cmd-Q to quit Finder
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = false;
      TrackpadRightClick = true;
    };

    screencapture = {
      type = "png";
      disable-shadow = true;
    };

    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    loginwindow = {
      GuestEnabled = false;
    };

    WindowManager = {
      GloballyEnabled = false;                  # disable Stage Manager
      EnableStandardClickToShowDesktop = false;
    };

    # "Displays have separate Spaces" must stay on (false) while rift-grid is the WM: otherwise it exits at once
    # and KeepAlive makes a silent crash loop (`launchctl print gui/$UID/org.nixos.rift-grid`: last exit code = 1).
    # WindowServer only reads it at login, so a change needs a logout.
    spaces.spans-displays = false;

    menuExtraClock = {
      Show24Hour = true;
      ShowDayOfWeek = true;
    };

    # Settings without a typed nix-darwin option, written via `defaults`.
    # These are scalar leaf values, so they don't clobber other keys in the domain.
    CustomUserPreferences = {
      NSGlobalDomain = {
        NSWindowShouldDragOnGesture = true;   # Ctrl+Cmd + drag moves a window
      };
      "com.apple.finder" = {
        NewWindowTarget = "PfHm";             # new Finder windows open Home
        NewWindowTargetPath = "file:///Users/${user}/";
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;      # no .DS_Store on network drives
        DSDontWriteUSBStores = true;          # no .DS_Store on USB drives
      };
    };

    # No _HIHideMenuBar: rift-grid draws its workspace indicator in the menu bar
    # ([settings.ui.menu_bar] in modules/darwin/rice/rift-grid/config.toml).
  };

  # "Select next source in Input menu" → F18; kanata sends Right Command as F18, making it 한/영.
  # `defaults -dict-add` merges just key 61 — CustomUserPreferences would overwrite all of AppleSymbolicHotKeys.
  # params = [ char keycode modifiers ]; 65535 = no char, 79 = F18, 8388608 = fn flag.
  system.activationScripts.postActivation.text = ''
    echo "configuring input-source hotkey (next source = F18)..." >&2
    # NOTE: must be XML plist with <true/> — an old-style `enabled=1` writes an
    # integer, which macOS treats as "not enabled" and reverts to the default.
    /usr/bin/sudo -u ${user} /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
      '<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>8388608</integer></array></dict></dict>'
    # reload so it applies without a full logout (best-effort)
    /usr/bin/sudo -u ${user} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
  '';
}
