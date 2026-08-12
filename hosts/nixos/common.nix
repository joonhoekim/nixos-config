{ config, pkgs, lib, user, home-manager, ... }:

# Hardware-agnostic system config shared by every NixOS host. Per-machine
# bits (hardware-configuration.nix, hostname, GPU/CPU tweaks) live in the
# host dirs (./mn56, ./evo-t1, ./galaxy-chromebook-1) that import this file.
# Vendor-common layers shared by several hosts live in modules/nixos
# (amd.nix, intel.nix).
#
# `home-manager` 는 flake input 이다 — specialArgs 가 input 을 이름 그대로
# 풀어 주므로 여기서 인자로 받는다. darwin 쪽이 자기 home-manager 배선을
# modules/darwin/home-manager.nix 에 두는 것과 같은 모양으로, NixOS 쪽 배선도
# flake.nix 가 아니라 이 파일에 있다(아래 home-manager 블록).

{
  imports = [
    home-manager.nixosModules.home-manager
    # Korean locale, IME (fcitx5-hangul), and CJK fonts.
    ../../modules/nixos/korean.nix
    # keyd remaps: Right Alt -> Hangul, and a nav layer on held Caps Lock.
    ../../modules/nixos/keyboard.nix
    # The pointer half of that layer — keyd cannot move a pointer, so the
    # left hand goes out as sentinel keys and this daemon drives the cursor.
    ../../modules/nixos/pointer
    # niri session + DankMaterialShell, offered alongside GNOME at the
    # tuigreet greeter and set as the default session below.
    ../../modules/nixos/niri
    # ...and a Hyprland session next to it, running the same shell. It exists
    # for what niri cannot do — an output-wide shader — so it is a peer of the
    # niri session, not a replacement.
    ../../modules/nixos/hyprland
    # DMS plugins shared by both sessions. The shell itself is enabled in
    # ../../modules/nixos/niri; this is only what sits on top of it.
    ../../modules/nixos/dms
    ../../modules/shared
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Rename rather than refuse. home-manager aborts the whole activation
    # when a file it wants to link already exists as a real file, and that
    # takes the rebuild down with it — which is exactly what happened on
    # galaxy-chromebook-1 once DMS had written ~/.config/gtk-*/settings.ini
    # itself.
    #
    # This repo deliberately leaves most of $HOME writable so the desktop can
    # tune itself, so that collision is a standing risk rather than a one-off.
    # A backup copy is a better outcome than a machine that cannot rebuild.
    backupFileExtension = "hm-bak";
    # Thread `user` into home-manager modules (separate arg scope from the
    # system modules' specialArgs).
    extraSpecialArgs = { inherit user; };
    users.${user} = import ../../modules/nixos/home-manager.nix;
  };

  # Boot — systemd-boot EFI loader. The disk/initrd kernel modules
  # (availableKernelModules, fileSystems, swap) and CPU microcode come from
  # each host's hardware-configuration.nix, not hardcoded here.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 42;
      };
      efi.canTouchEfiVariables = true;
    };
    # linuxPackages_latest keeps recent CPUs/GPUs (Ryzen 7840HS, Intel
    # 14900HX / 285H) well-supported.
    kernelPackages = pkgs.linuxPackages_latest;
    # uinput is required by keyd (see modules/nixos/keyboard.nix).
    kernelModules = [ "uinput" ];
  };

  time.timeZone = "Asia/Seoul";

  # hostName is set per-host (see ./mn56, ./evo-t1, ./galaxy-chromebook-1).
  networking.networkmanager.enable = true;

  # Turn on flag for proprietary software
  nix = {
    # nix.nixPath is deliberately NOT set. It used to carry
    #   [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ]
    # — a dustinlyons-template leftover that pointed at a directory none of
    # these machines has (the repo lives at ~/nixos-config on all three), and
    # nothing in this repo ever read it.
    #
    # The real damage was the second-order kind. nixos/modules/misc/
    # nixpkgs-flake.nix gives every flake-built system
    #   nix.nixPath = lib.mkDefault [ "nixpkgs=flake:nixpkgs" ... ];
    # and mkDefault loses to any plain definition — so that one line silently
    # dropped `nixpkgs=` from NIX_PATH, and `nix-shell -p foo` /
    # `nix-build '<nixpkgs>' -A hello` failed with "file 'nixpkgs' was not
    # found in the Nix search path" on every NixOS host here. (`nix run
    # nixpkgs#hello` kept working — that goes through nix.registry, which the
    # same module sets from a separate block.)
    #
    # Leaving the option alone restores the module's default. There is no
    # replacement `nixos-config=` entry because there cannot be a working one:
    # <nixos-config> wants a file (a directory needs default.nix, and the repo
    # root only has flake.nix), and pointing it at a host's own default.nix
    # would not evaluate either — ./common.nix takes `home-manager` from
    # specialArgs, which only exists inside the flake.
    settings = {
      # `@wheel`, not the `@admin` this once carried: `admin` is the macOS
      # administrators group (see hosts/darwin, where it is correct). NixOS has
      # no such group, so nix warned about it and ignored the entry. Both lists
      # name the group because a wheel member who could not even connect to the
      # daemon made "trusted" meaningless. root is always allowed and trusted,
      # regardless of what is listed here.
      allowed-users = [ "@wheel" "${user}" ];
      trusted-users = [ "@wheel" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];

      # Recover faster from stuck substituter connections on flaky networks.
      stalled-download-timeout = 60; # default 300s
      connect-timeout = 10;          # default 5s
    };

    # Store housekeeping. `systemd-boot.configurationLimit` above only trims
    # the *boot menu*; it does not drop the profile generations, and a
    # generation that still exists is a GC root. Without this the store grows
    # monotonically until the 42-generation cap is reached (it sat at 56G / 28
    # generations before this was added).
    #
    # `dates`/`options` are the systemd-timer spelling — hosts/darwin uses
    # `interval` with a launchd calendar attrset for the same effect.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Hardlink identical files across the store. Runs as its own timer rather
    # than `settings.auto-optimise-store`, which does the same work inline on
    # every build and slows them down.
    optimise.automatic = true;

    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs = {
    # Manages keys and such
    gnupg.agent.enable = true;

    # Needed for anything GTK related
    dconf.enable = true;

    # My shell
    zsh.enable = true;

    # A real dynamic loader at /lib64/ld-linux-x86-64.so.2, replacing the
    # NixOS stub that aborts with "Could not start dynamically linked
    # executable". mise fetches generic-linux prebuilt binaries for bun,
    # temurin java and rustup-init (see modules/shared/programs/cli.nix);
    # without this they all die at exit 127 the moment mise verifies them.
    # node survives regardless — mise falls back to compiling it from source
    # — and go is statically linked, which is why those two alone worked.
    nix-ld.enable = true;
  };

  services = {
    # ── Desktop: Wayland sessions via greetd/tuigreet ──────────────────
    # xserver provides Xwayland + xkb config even on a Wayland session.
    xserver = {
      enable = true;
      # Layout only. Key remaps go through keyd (modules/nixos/keyboard.nix),
      # not xkb.options: niri and GNOME both build their keymaps themselves and
      # ignore what is set here, so an xkb-level remap only reaches X11 apps.
      xkb.layout = "us";
    };

    # greetd + tuigreet replaces GDM: a TUI greeter on VT1, with none of the
    # GNOME stack (gnome-shell, gnome-session) running behind the login screen.
    #
    # `--sessions` points at the very same sessionData.desktops derivation GDM
    # consumed, so every session entry still appears — gnome.desktop comes from
    # `desktopManager.gnome.enable`, niri.desktop from programs.niri.enable, and
    # hyprland{,-uwsm}.desktop from programs.hyprland.enable (the package
    # provides both; take the uwsm one, see modules/nixos/hyprland).
    # Nothing about session *discovery* changes, only the greeter in front of it.
    #
    # useTextGreeter rewires the unit's stdio onto /dev/tty1 (TTYReset, VHangup,
    # VTDisallocate) so kernel/boot messages don't scribble over the TUI.
    #
    # Keyring note: the greetd PAM service is `auth substack login` +
    # `session include login`, i.e. it inherits /etc/pam.d/login wholesale —
    # and that stack already carries pam_gnome_keyring's auth + session rules.
    # So gnome-keyring still auto-unlocks at login without GDM. Setting
    # `security.pam.services.greetd.enableGnomeKeyring` would be a no-op here:
    # the greetd service sets useDefaultRules = false, which is exactly the
    # block those generated keyring rules live in.
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = lib.concatStringsSep " " [
        # Top-level `pkgs.tuigreet`, not `pkgs.greetd.tuigreet` — most guides
        # still show the latter, but `pkgs.greetd` is the greetd derivation
        # itself in this nixpkgs, not a package set, so that path errors out.
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember" # prefill the last username
        "--remember-session" # ...and the session it last launched
        "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
      ];
    };

    # Consumed by the assertion in services/display-managers/default.nix, which
    # requires this to be one of sessionData.sessionNames
    # ("gnome" | "niri" | "hyprland" | "hyprland-uwsm").
    # tuigreet itself does not read it — `--remember-session` is what actually
    # makes a login land back in niri, from the second login onward.
    displayManager.defaultSession = "niri";

    # GNOME stays installed but is no longer the default session. It is the
    # fallback when a niri/Quickshell bump breaks the desktop, and it is the
    # only thing pulling in gnome-keyring and seahorse — nothing in this repo
    # declares either directly, so dropping this line silently removes both.
    desktopManager.gnome.enable = true;

    # Better support for general peripherals
    libinput.enable = true;

    # Periodic SSD TRIM.
    fstrim.enable = true;

    # smartd is enabled per host (./mn56, ./evo-t1 — the note there explains
    # why it cannot go in this file), but *how its alarms get delivered* is not
    # a per-host question, so it is answered once here and applies to whichever
    # host runs the daemon.
    #
    # x11 is off because it could never have worked. The option defaults to on
    # whenever services.xserver.enable is set — which it is, above, for
    # Xwayland and xkb — and then hardcodes DISPLAY=:0. Every session on these
    # machines is Wayland, so :0 is at best some Xwayland instance and at worst
    # nothing at all. A warning sent there is a warning lost.
    #
    # systembus-notify is the replacement. smartd runs as root and desktop
    # notifications are per-user, so the alarm has to cross that boundary;
    # this is the bridge that carries it, and turning it on here also flips
    # services.systembus-notify on (the smartd module does that with mkDefault).
    # Its own module warns that any local user can then spam the session with
    # notifications — irrelevant on a single-user desktop, worth remembering if
    # that ever stops being true.
    #
    # wall stays on underneath as the fallback that needs no session at all:
    # it reaches a TTY even when the desktop is the thing that is broken.
    #
    # One gotcha on the rebuild that first enables this: the user unit is
    # wantedBy=graphical-session.target, and a target that is *already* active
    # does not start newly-installed wants. So it sits inactive until the next
    # login (or a manual `systemctl --user start systembus-notify`) even though
    # the switch reported success.
    #
    # Verified by running the generated smartd-notify.sh by hand as root with
    # SMARTD_DEVICESTRING/SMARTD_MESSAGE set: the signal crosses the system bus
    # and the notification lands on the desktop.
    smartd.notifications = {
      systembus-notify.enable = true;
      wall.enable = true;
      x11.enable = false;
    };

    # Tray-toggleable power profiles (Power Saver / Balanced / Performance),
    # which GNOME's quick settings drive. Mutually exclusive with tlp and
    # auto-cpufreq — don't enable those alongside it.
    power-profiles-daemon.enable = true;

    # Let's be able to SSH into this machine. No authorized keys are declared,
    # so access is by account password (set imperatively with `passwd`). To use
    # key auth instead, add your own pubkey to the user below.
    openssh.enable = true;

    # Printing
    printing.enable = true;

    # ── Audio via PipeWire ─────────────────────────────────────────────
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  # Lets PipeWire acquire realtime scheduling priority
  security.rtkit.enable = true;

  # Don't let activation restart the *session* bus. The generated user
  # dbus-broker unit embeds store paths (PATH, LOCALE_ARCHIVE, TZDIR,
  # X-Restart-Triggers), so nearly every nixpkgs bump marks it changed — and
  # switch-to-configuration talks to the user manager over that very bus
  # (LocalConnection::new_session()), then waits for the job's JobRemoved
  # signal in a loop with no timeout. Restarting the broker drops that
  # connection, so the signal never arrives and `nixos-rebuild switch` stalls
  # at "restarting the following user units: dbus-broker.service".
  #
  # X-RestartIfChanged=false moves it to the skip list ("NOT restarting the
  # following user units: ..."). The running bus then keeps its old
  # environment until the next login, which is what upstream wants anyway —
  # see nixos/modules/services/system/dbus.nix: "Don't restart dbus. Bad
  # things tend to happen if we do."
  #
  # reloadIfChanged has to go too, and with mkForce: dbus.nix sets it to true,
  # and systemd-lib.nix emits these as an if/else chain (X-ReloadIfChanged
  # wins and X-RestartIfChanged is never written). The cost is that the user
  # bus no longer picks up new D-Bus service/activation files on rebuild —
  # a re-login does that instead.
  systemd.user.services.dbus-broker = {
    reloadIfChanged = lib.mkForce false;
    restartIfChanged = false;
  };

  # RAM-compressed swap — relieves memory pressure (zstd).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ...and tune the VM for it. Both kernel defaults assume swap is a slow
  # rotating disk, which is exactly what zram is not.
  #
  # swappiness 60 -> 180: the default rations swap-outs because each one used
  # to cost a seek. A zram page-out is a zstd compression at RAM speed, so
  # trading anonymous pages for page cache is nearly free and should be the
  # kernel's *preferred* move under pressure. 200 is the ceiling (raised from
  # 100 in 5.8 specifically for this case).
  #
  # page-cluster 3 -> 0: 3 means "read 2^3 = 8 pages per swap-in". Readahead
  # amortises seek latency on a disk; on zram there is no seek, so the 7 extra
  # pages are 7 extra decompressions that usually go unused.
  #
  # A host that also declares a disk swap partition gets the right ordering
  # for free: zram0 sits at priority 5 and a partition at -1, so
  # zram always fills first and the disk is only touched once zram is
  # exhausted. That layering is the whole point — the disk is the backstop, not
  # the first stop. (mn56's partition used to hold a hibernate image too; that
  # is gone, and only the backstop role remains. See ./mn56.)
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  # /tmp is not a separate mount here — it is a plain directory on the ext4
  # root, so anything left behind survives reboots and accumulates forever.
  # Clear it at boot instead.
  #
  # Deliberately not `boot.tmp.useTmpfs`: the nix daemon builds in /tmp, and a
  # RAM-backed one turns any large build into an out-of-space failure.
  boot.tmp.cleanOnBoot = true;

  # GPU / video acceleration. AMD (amdgpu) and modern Intel (i915/xe) are both
  # covered by mesa out of the box for *rendering*. Video decode is where they
  # part: radeonsi carries VAAPI with it, Intel needs intel-media-driver added
  # explicitly — which is what ../../modules/nixos/intel.nix does, alongside
  # ../../modules/nixos/amd.nix. Anything narrower than a vendor goes in the
  # host dir.
  hardware.graphics.enable = true;

  # Add docker daemon
  virtualisation.docker = {
    enable = true;
    logDriver = "json-file";
    # json-file has no rotation of its own — a container that logs steadily
    # will grow /var/lib/docker/containers until the root filesystem is full,
    # with nothing in the unit or the journal to hint at where the space went.
    # These are daemon-wide defaults; a container can still override them with
    # its own --log-opt.
    daemon.settings.log-opts = {
      max-size = "10m";
      max-file = "3";
    };
  };

  users.users = {
    ${user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"          # Enable 'sudo' for the user.
        "networkmanager"
        "docker"
      ];
      shell = pkgs.zsh;
    };
  };

  # wheel users can sudo without a password (carried over preference).
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # General fonts (shared Nerd Fonts + a couple of extras). Korean/CJK
  # fonts and fontconfig fallbacks live in modules/nixos/korean.nix.
  fonts.packages = (import ../../modules/shared/fonts.nix { inherit pkgs; }) ++ (with pkgs; [
    dejavu_fonts
    jetbrains-mono
  ]);

  environment.systemPackages = with pkgs; [
    gitFull
    inetutils
  ];

  # Match the release your machine was first installed at. Don't change
  # this casually — it pins stateful-data compatibility, not the channel.
  # 26.11 is just the value this repo's nixos-unstable checkout carries; it is
  # NOT what a fresh install gets. Whatever nixos-generate-config wrote on the
  # target machine (e.g. 26.05 from a 26.05 installer) is the correct value for
  # that host, so every host pins its own and this stays mkDefault
  # (see ./mn56 = 26.05, ./evo-t1 = 26.05, ./galaxy-chromebook-1 = 25.11).
  system.stateVersion = lib.mkDefault "26.11";
}
