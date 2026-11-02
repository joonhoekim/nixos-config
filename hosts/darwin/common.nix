{ config, lib, pkgs, user, ... }:

let
  # 앱이 없는데 `open -a` 를 남기면 로그인마다 실패하고 apps/check/mac 이 그 job 을 ✗ 로 보인다.
  hasCask = name: builtins.elem name (map (c: c.name) config.homebrew.casks);
in

{
  imports = [
    ../../modules/darwin/home-manager.nix
    ../../modules/darwin/default-apps.nix
    ../../modules/darwin/ios.nix
    # Caps Lock 레이어와 한/영(오른쪽 ⌘ → F18). 레이어는 Windows 와 같은 파일이다.
    ../../modules/darwin/kanata.nix
    # launchd 서비스가 Background App Activity 에 "sh" 가 아니라 제 이름으로 보이게.
    ../../modules/darwin/launchd-names.nix
    ../../modules/darwin/rice
    ../../modules/shared
  ];

  # nix.package 는 local.nix.implementation 이 정한다 (modules/shared/nix-implementation.nix).
  nix = {
    settings = {
      trusted-users = [ "@admin" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      # substituters 의 캐시마다 키가 있어야 한다. 키가 없는 캐시의 경로는 require-sigs 에
      # 걸려 전부 버려지는데, 빌드는 실패하지 않고 로컬 빌드로 조용히 넘어간다.
      # nix-community 키의 출처: https://app.cachix.org/api/v1/cache/nix-community
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
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

  # Passwordless sudo. sudoers.d is included at the end of /etc/sudoers, so it wins over `%admin ALL=(ALL) ALL`.
  # It bypasses the Touch ID prompt above: anything running as ${user}, background agents included, reaches root unprompted.
  security.sudo.extraConfig = ''
    ${user} ALL=(ALL) NOPASSWD: ALL
  '';

  # Apps' own start-at-login toggles don't stick on recent macOS, so login items are per-user LaunchAgents.
  launchd.user.agents = {
    # rift-grid is built and signed per machine by apps/rift-grid, not nix or brew: TCC ties its grants to the
    # signature (reasoning at the top of apps/rift-grid). `path`: its keybindings shell out to rift-grid-cli and
    # systemPath tools, and a LaunchAgent inherits none of a login shell's PATH.
    rift-grid = {
      command = "/Users/${user}/.local/bin/rift-grid";
      path = [ "/Users/${user}/.local/bin" config.environment.systemPath ];
      # Unset, tracing's EnvFilter keeps only errors: an app it gave up attaching to leaves no line in the log.
      environment.RUST_LOG = "warn";
      serviceConfig = {
        RunAtLoad = true;
        # Plain KeepAlive would restart-loop until apps/rift-grid builds the binary; PathState waits for it.
        KeepAlive.PathState."/Users/${user}/.local/bin/rift-grid" = true;
        # Without these, refusal reasons and run_on_start failures go to an unread stdout — the WM just silently doesn't run.
        StandardOutPath = "/tmp/rift-grid.log";
        StandardErrorPath = "/tmp/rift-grid.log";
      };
    };
    # Driven from launchd, not Stats' own SMAppService login item that the app rewrites from its prefs.
    # `open -a` as with linearmouse below: if that in-app toggle is ever on, a direct exec gives two Stats
    # (`sudo sfltool dumpbtm` prints both dispositions). 전체 그림: docs/macos-internals.md
    stats = lib.mkIf (hasCask "stats") {
      command = "/usr/bin/open -a /Applications/Stats.app";
      serviceConfig.RunAtLoad = true;
    };


    # 외장 마우스 휠만 뒤집는다(설정과 근거: modules/darwin/rice/linearmouse/README.md).
    # Mach-O 직접 exec 이 아니라 `open -a` 여야 앱 자체 로그인 항목과 겹쳐도 하나만 뜬다. 둘이 뜨면 서로
    # 상쇄해 "아이콘 둘 + 휠 방향 그대로"로 보인다. 전체 그림: docs/macos-internals.md
    linearmouse = lib.mkIf (hasCask "linearmouse") {
      command = "/usr/bin/open -a /Applications/LinearMouse.app";
      serviceConfig.RunAtLoad = true;
    };
  };

  # environment.systemPackages 는 두지 않는다 — shared 패키지는 home.packages 로 들어가 여기 넣으면 이중으로 깔린다.

  # Fonts in systemPackages are NOT picked up by macOS apps, so terminals show broken glyphs without this.
  fonts.packages = import ../../modules/shared/fonts.nix { inherit pkgs; } ++ [
    # OnlyOffice 한글 폴백이 Heiti 로 가는 것을 막는 macOS 전용 별칭(overlays/onlyoffice-batang-alias.nix).
    pkgs.onlyoffice-batang-alias
  ];

  system = {
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 5;

    defaults = {
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
