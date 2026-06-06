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
    };
  };
}
