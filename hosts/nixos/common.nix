{ config, inputs, pkgs, lib, user, ... }:

# Hardware-agnostic system config shared by every NixOS host. Per-machine
# bits (hardware-configuration.nix, hostname, GPU/CPU tweaks) live in the
# host dirs (./mn56, ./galaxy-chromebook-1) that import this file.
# Vendor-common layers shared by several hosts live in modules/nixos
# (e.g. amd.nix).

{
  imports = [
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
    ../../modules/shared
  ];

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

  # hostName is set per-host (see ./mn56, ./galaxy-chromebook-1).
  networking.networkmanager.enable = true;

  # Turn on flag for proprietary software
  nix = {
    nixPath = [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ];
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
    # ── Desktop: niri on Wayland via greetd/tuigreet ───────────────────
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
    # consumed, so both session entries still appear — gnome.desktop comes from
    # `desktopManager.gnome.enable` and niri.desktop from programs.niri.enable.
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
    # requires this to be one of sessionData.sessionNames ("gnome" | "niri").
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

  # GPU / video acceleration. AMD (amdgpu) and modern Intel (i915/xe) are both
  # covered by mesa out of the box. Anything beyond that is per-machine and
  # goes in the host dir — an Intel box wanting VAAPI/QSV decode adds
  # intel-media-driver to hardware.graphics.extraPackages there.
  hardware.graphics.enable = true;

  # Add docker daemon
  virtualisation.docker = {
    enable = true;
    logDriver = "json-file";
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
  # (see ./mn56 = 26.05, ./galaxy-chromebook-1 = 25.11).
  system.stateVersion = lib.mkDefault "26.11";
}
