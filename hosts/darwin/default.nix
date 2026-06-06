{ config, pkgs, ... }:

let user = "jh"; in

{
  imports = [
    ../../modules/darwin/home-manager.nix
    ../../modules/shared
  ];

  nix = {
    package = pkgs.nix;

    settings = {
      trusted-users = [ "@admin" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };

    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };


  environment.systemPackages =
    import ../../modules/shared/packages.nix { inherit pkgs; };

  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 5;

    defaults = {
      NSGlobalDomain = {
        # Appearance
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;

        # Keyboard
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

        # Expand save/print panels by default
        NSNavPanelExpandedStateForSaveMode = true;
        PMPrintingExpandedStateForPrint = true;

        # Don't default new documents to iCloud
        NSDocumentSaveNewDocumentsToCloud = false;

        # Mouse / sound
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      dock = {
        autohide = false;
        show-recents = false;
        launchanim = true;
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
        TrackpadThreeFingerDrag = true;
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
    };

    # "Select next source in Input menu" → F18 (so Karabiner can drive
    # input-source switching). We merge just key 61 with `defaults -dict-add`
    # rather than system.defaults.CustomUserPreferences, which would overwrite
    # the entire AppleSymbolicHotKeys dict and wipe other shortcuts (Spotlight, etc).
    # params = [ char keycode modifiers ]; 65535 = no char, 79 = F18, 8388608 = fn flag.
    activationScripts.postActivation.text = ''
      echo "configuring input-source hotkey (next source = F18)..." >&2
      # NOTE: must be XML plist with <true/> — an old-style `enabled=1` writes an
      # integer, which macOS treats as "not enabled" and reverts to the default.
      /usr/bin/sudo -u ${user} /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
        '<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>8388608</integer></array></dict></dict>'
      # reload so it applies without a full logout (best-effort)
      /usr/bin/sudo -u ${user} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
    '';
  };
}
