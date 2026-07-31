{ config, inputs, pkgs, lib, user, ... }:

# Hardware-agnostic system config shared by every NixOS host. Per-machine
# bits (hardware-configuration.nix, hostname, GPU/CPU tweaks) live in the
# host dirs (./mn56, ./intel, ./galaxy-chromebook-1) that import this file.
# Vendor-common layers shared by several hosts live in modules/nixos
# (e.g. amd.nix).

{
  imports = [
    # Korean locale, IME (fcitx5-hangul), Right Alt -> Hangul, and CJK fonts.
    ../../modules/nixos/korean.nix
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
    # uinput is required by keyd (Right Alt -> Hangul remap; see korean.nix).
    kernelModules = [ "uinput" ];
  };

  time.timeZone = "Asia/Seoul";

  # hostName is set per-host (see ./mn56, ./intel).
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
  };

  services = {
    # ── Desktop: GNOME on Wayland via GDM ──────────────────────────────
    # xserver provides Xwayland + xkb config even on a Wayland session.
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        options = "ctrl:nocaps"; # Caps Lock -> Ctrl
      };
    };
    # GDM defaults to a Wayland session; no extra wayland.enable needed.
    displayManager.gdm.enable = true;
    displayManager.defaultSession = "gnome";
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
  # covered by mesa out of the box; per-host extraPackages (e.g. Intel VAAPI)
  # are added in the host dirs.
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
