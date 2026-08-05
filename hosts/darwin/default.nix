{ config, pkgs, user, ... }:

{
  imports = [
    ../../modules/darwin/home-manager.nix
    ../../modules/darwin/default-apps.nix
    ../../modules/darwin/eul.nix
    ../../modules/darwin/ios.nix
    ../../modules/darwin/rice
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

  # Touch ID (and Apple Watch) for sudo. `reattach` makes it work inside tmux.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # Passwordless sudo, so every machine gets it from this repo instead of a
  # hand-edited visudo. Lands in /etc/sudoers.d/10-nix-darwin-extra-config,
  # which macOS's /etc/sudoers already includes — and because the include sits
  # at the end, this rule wins over the default `%admin ALL=(ALL) ALL`.
  #
  # This bypasses the Touch ID prompt above entirely: anything running as
  # ${user}, including background agents, can reach root without confirmation.
  # The prompt still applies to other users.
  security.sudo.extraConfig = ''
    ${user} ALL=(ALL) NOPASSWD: ALL
  '';

  # Launch GUI apps at login (declarative "Login Items"). The apps' own
  # start-at-login toggles don't stick on recent macOS, so we drive them
  # via per-user LaunchAgents instead.
  launchd.user.agents = {
    # Tiling WM — keep it alive so a crash/quit relaunches it.
    #
    # rift replaced AeroSpace here. AeroSpace itself is still installed (see
    # modules/darwin/casks.nix) and its config still lives in this repo; only
    # the login agent moved. That is the escape hatch: if rift misbehaves,
    # `open -a AeroSpace` puts the old WM back this second, no rebuild. Kill
    # rift first (`launchctl bootout gui/$UID/org.nixos.rift`) — two tiling
    # WMs fighting over the same windows is worse than either alone.
    #
    # The binary comes from a brew formula (modules/darwin/brews.nix), so this
    # is /opt/homebrew, not /nix/store. `path` matters: rift's run_on_start
    # hook shells out to `borders` (nix store, reached via systemPath) and its
    # keybindings reach `rift-cli` (sibling in /opt/homebrew/bin) — and a
    # LaunchAgent inherits none of a login shell's PATH.
    rift = {
      command = "/opt/homebrew/bin/rift";
      path = [ "/opt/homebrew/bin" config.environment.systemPath ];
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        # Not optional in practice. Without these, rift's output goes nowhere:
        # the first time it refused to start (see
        # docs/postmortems/2026-08-04-macos-rift-sketchybar.md) the reason was
        # printed to a stdout nobody was reading, and the only visible symptom
        # was a WM that silently did not run. run_on_start failures are the
        # same shape — a hook that never fires leaves no trace at all.
        StandardOutPath = "/tmp/rift.log";
        StandardErrorPath = "/tmp/rift.log";
      };
    };
    # Menu-bar system monitor — start at login, but respect a manual quit.
    eul = {
      command = "/Applications/eul.app/Contents/MacOS/eul";
      serviceConfig.RunAtLoad = true;
    };

    # Workspace-switcher overlay (Option+Ctrl+W). Same shape as eul: start it,
    # but a manual quit stays quit.
    #
    # It has to be here because the app registers no Login Item of its own —
    # its install.sh builds and signs the bundle and stops there. Nothing was
    # starting it, so after every reboot the hotkey did nothing while the app
    # looked perfectly installed.
    #
    # nix does not install this one; it is a Swift .app built imperatively
    # (modules/darwin/rice/peek/README.md). On a machine where it has not been
    # built yet this agent fails once at login and is never retried — which is
    # the behaviour we want, not a restart loop. `command -v` cannot guard a
    # LaunchAgent, and KeepAlive would turn the absence into one.
    #
    # Launching the bundle's Mach-O directly, rather than `open -a`, is
    # deliberate and was verified rather than assumed: the app is ad-hoc signed
    # (TeamIdentifier not set), and TCC entries for ad-hoc binaries are keyed to
    # the cdhash, so it was worth checking that a launchd start still resolves
    # the Accessibility grant. It does — CGGetEventTapList shows the same
    # enabled event tap either way. `open -a` would exit immediately and leave
    # launchd thinking the job finished, which is a worse fit for RunAtLoad.
    workspacepeek = {
      command = "/Applications/WorkspacePeek.app/Contents/MacOS/WorkspacePeek";
      # Reaches rift-cli — the overlay asks rift for the workspace list every
      # time it opens (config.json: windowManager.backend = "auto"). Without
      # this the overlay draws but finds no workspaces.
      path = [ "/opt/homebrew/bin" config.environment.systemPath ];
      serviceConfig.RunAtLoad = true;
    };
  };

  environment.systemPackages =
    import ../../modules/shared/packages.nix { inherit pkgs; };

  # Register fonts with the macOS font system (symlinked into
  # /Library/Fonts/Nix Fonts). Fonts in systemPackages are NOT picked up by
  # macOS apps, so terminals show broken glyphs without this.
  fonts.packages = import ../../modules/shared/fonts.nix { inherit pkgs; };

  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 5;

    defaults = {
      NSGlobalDomain = {
        # Appearance
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        AppleShowScrollBars = "Always";   # always show scroll bars

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
        autohide = true;
        # Snappy reveal: no dwell time before it slides out, and a short
        # animation. Both are floats macOS reads as seconds — 0.5/1.0 are the
        # stock values, which feel sluggish next to a tiling WM.
        autohide-delay = 0.0;
        autohide-time-modifier = 0.2;
        show-recents = false;
        launchanim = true;
        # Bottom, not right. The scrolling layout in rift moves windows
        # horizontally, so a right-edge Dock sits exactly where columns enter
        # and leave the screen — every reveal collides with the strip. At the
        # bottom it only ever eats vertical space, which the layout has to
        # spare. (This was "right" while AeroSpace tiled in both directions.)
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

      # Mission Control > "Displays have separate Spaces".
      #
      #   false = each display gets its own Spaces (macOS default)
      #   true  = one Space spans every display
      #
      # This is a hard requirement of the window manager, and the two WMs this
      # repo has used want OPPOSITE values. AeroSpace wanted `true`, which is
      # what this line said until rift replaced it. rift refuses to start
      # otherwise — not a degraded mode, an immediate exit:
      #
      #   Rift detected that the macOS setting "Displays have separate Spaces"
      #   is disabled. Rift currently requires this setting to be enabled.
      #
      # And because the LaunchAgent has KeepAlive, that exit becomes a crash
      # loop that looks like "rift just doesn't run" — `launchctl print
      # gui/$UID/org.nixos.rift` showing `last exit code = 1` is the tell.
      # Running /opt/homebrew/bin/rift in a terminal prints the reason; the
      # agent's stdout goes nowhere.
      #
      # So: leave this at `false` for as long as rift is the WM. Flipping it
      # back is part of reverting to AeroSpace, not an independent knob.
      #
      # A logout is required either way — the value lands in
      # com.apple.spaces immediately, but WindowServer only reads it at login.
      # rift's own check reads the preference, so it will start before the
      # logout while windows still behave the old way.
      #
      # (The companion "Automatically rearrange Spaces" toggle is handled
      # above via dock.mru-spaces = false.)
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

      # No _HIHideMenuBar here. It was left off while sketchybar was competing
      # for the same strip, and now there is nothing to compete: the menu bar
      # is where rift draws its workspace indicator
      # ([settings.ui.menu_bar] in modules/darwin/config/rift.toml), so hiding
      # it would hide the one thing this setup added to it.

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
