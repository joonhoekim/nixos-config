{ config, pkgs, lib, user, identity, home-manager, subline, ... }:

# 전체 그림: docs/02-this-repo.md, 이 파일의 설계 배경: docs/nixos-common.md

{
  imports = [
    home-manager.nixosModules.home-manager
    ../../modules/nixos/korean.nix
    ../../modules/nixos/gui-apps.nix
    ../../modules/nixos/keyboard.nix
    ../../modules/nixos/pointer
    ../../modules/nixos/subline
    ../../modules/nixos/subline-terminal.nix
    ../../modules/nixos/niri
    ../../modules/nixos/hyprland
    ../../modules/nixos/dms
    ../../modules/nixos/wireguard.nix
    ../../modules/shared
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Rename rather than refuse: home-manager aborts the whole activation (and the
    # rebuild) when a target already exists as a real file, and $HOME stays writable.
    backupFileExtension = "hm-bak";
    # Separate arg scope from system specialArgs. `subline` feeds subline-tts
    # (modules/nixos/nautice.nix).
    extraSpecialArgs = { inherit user identity subline; bundles = config.local.packages.bundles; };
    users.${user} = import ../../modules/nixos/home-manager.nix;
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 42;
      };
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    # keyd needs uinput (modules/nixos/keyboard.nix).
    kernelModules = [ "uinput" ];
  };

  time.timeZone = "Asia/Seoul";

  # hostName 은 flake.nix 의 mkNixosHost 가 디렉토리 이름으로 mkDefault 한다.
  networking.networkmanager.enable = true;

  nix = {
    # nix.nixPath is deliberately unset: any plain definition beats the mkDefault
    # `nixpkgs=flake:nixpkgs` of nixos/modules/misc/nixpkgs-flake.nix, and
    # `nix-shell -p` / `<nixpkgs>` then fail. No nixos-config= either: docs/nixos-common.md
    settings = {
      # `@wheel`, not `@admin` (a macOS group; NixOS has none, so nix ignores it).
      # Both lists need it: trusted is moot if the daemon refuses the connection.
      allowed-users = [ "@wheel" "${user}" ];
      trusted-users = [ "@wheel" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      # substituters 의 캐시마다 키가 있어야 한다. 키가 없는 캐시의 경로는 require-sigs 에
      # 걸려 전부 버려지는데, 빌드는 실패하지 않고 로컬 빌드로 조용히 넘어간다.
      # nix-community 키의 출처: https://app.cachix.org/api/v1/cache/nix-community
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Recover faster from stuck substituter connections on flaky networks.
      stalled-download-timeout = 60; # default 300s
      connect-timeout = 10;          # default 5s
    };

    # configurationLimit only trims the boot menu; generations stay GC roots, so
    # without this the store only grows (56G at 28 generations, measured).
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Own timer rather than auto-optimise-store, which runs inline and slows every build.
    optimise.automatic = true;

    # package 는 local.nix.implementation 이 정한다 (modules/shared/nix-implementation.nix).
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs = {
    gnupg.agent.enable = true;

    # GTK apps need it to read and store their settings.
    dconf.enable = true;

    zsh.enable = true;

    # Real loader at /lib64/ld-linux-x86-64.so.2. Without it mise's generic-linux
    # prebuilts (bun, pnpm, temurin, rustup-init) die at exit 127.
    nix-ld.enable = true;
  };

  services = {
    # Xwayland + xkb config, even on Wayland sessions.
    xserver = {
      enable = true;
      # Layout only; remaps go through keyd. niri and GNOME ignore xkb.options,
      # so an xkb remap would reach X11 apps only.
      xkb.layout = "us";
    };

    # Fallback greeter (tuigreet): modules/nixos/subline overrides both mkDefaults
    # while local.subline.greeter is on. Sessions, keyring: docs/nixos-common.md
    greetd = {
      enable = true;
      useTextGreeter = lib.mkDefault true;
      settings.default_session.command = lib.mkDefault (lib.concatStringsSep " " [
        # Not `pkgs.greetd.tuigreet`: pkgs.greetd is the greetd derivation here,
        # not a package set, so that path errors out.
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember"
        "--remember-session"
        "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
      ]);
    };

    # Must be one of sessionData.sessionNames (assertion in
    # services/display-managers/default.nix); modules/nixos/subline sets "subline".
    displayManager.defaultSession = lib.mkDefault "niri";

    # Fallback session, and the only thing pulling in gnome-keyring and seahorse —
    # dropping this line silently removes both.
    desktopManager.gnome.enable = true;

    libinput.enable = true;

    fstrim.enable = true;

    # x11 off: it hardcodes DISPLAY=:0, which no Wayland session here owns, so alarms vanish.
    # systembus-notify carries root's alarm into the user session; wall reaches a TTY.
    # smartd itself is enabled per host. Details: docs/nixos-common.md
    smartd.notifications = {
      systembus-notify.enable = true;
      wall.enable = true;
      x11.enable = false;
    };

    # Mutually exclusive with tlp and auto-cpufreq.
    power-profiles-daemon.enable = true;

    # Keys come from users/<이름>.nix `authorizedKeys`; an empty list means password login.
    openssh.enable = true;

    printing.enable = true;

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  # Lets PipeWire acquire realtime scheduling priority.
  security.rtkit.enable = true;

  # Restarting the session bus drops switch-to-configuration's connection, so `nixos-rebuild
  # switch` hangs at "restarting ... dbus-broker.service". mkForce: dbus.nix sets reload,
  # which wins over restart in systemd-lib.nix. Details: docs/nixos-common.md
  systemd.user.services.dbus-broker = {
    reloadIfChanged = lib.mkForce false;
    restartIfChanged = false;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # zram has no seek: swappiness 180 (ceiling 200 since 5.8) prefers swapping out,
  # page-cluster 0 drops the 8-page readahead. Disk swap priority: docs/nixos-common.md
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  # /tmp is a plain dir on the ext4 root, so clear it at boot. Not useTmpfs: the nix
  # daemon builds in /tmp, and a RAM-backed one fails large builds for lack of space.
  boot.tmp.cleanOnBoot = true;

  # Intel's VAAPI driver is added in ../../modules/nixos/intel.nix.
  hardware.graphics.enable = true;

  # 켜면 dockerd·containerd 가 부팅부터 상주하므로 containers 묶음을 고른 호스트에서만 켠다.
  virtualisation.docker = {
    enable = builtins.elem "containers" config.local.packages.bundles;
    logDriver = "json-file";
    # json-file never rotates: a chatty container fills / with no hint in the unit or
    # journal. Daemon-wide defaults; a container's --log-opt still overrides.
    daemon.settings.log-opts = {
      max-size = "10m";
      max-file = "3";
    };
  };

  users.users = {
    ${user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ] ++ lib.optionals config.virtualisation.docker.enable [
        "docker"
      ];
      # 로그인 셸은 macOS 와 같은 bash 다. 에이전트의 셸 스크립트가 bash 를
      # 가정하고, subline-terminal 의 프롬프트 테마도 bash 에서만 돈다.
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = identity.authorizedKeys;
    };
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Korean/CJK fonts and fontconfig fallbacks: modules/nixos/korean.nix.
  fonts.packages = (import ../../modules/shared/fonts.nix { inherit pkgs; }) ++ (with pkgs; [
    dejavu_fonts
    jetbrains-mono
  ]);

  environment.systemPackages = with pkgs; [
    gitFull
    inetutils
  ];

  # Pins stateful-data compatibility, not the channel. Each host pins what
  # nixos-generate-config wrote there; 26.11 is only the mkDefault fallback.
  system.stateVersion = lib.mkDefault "26.11";
}
