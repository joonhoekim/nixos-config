{ config, inputs, pkgs, lib, ... }:

# Hardware-agnostic system config shared by every NixOS host. Per-machine
# bits (hardware-configuration.nix, hostname, GPU/CPU tweaks) live in the
# host dirs (./amd, ./intel) that import this file.

let
  user = "jh";
  # NOTE: replace with your own SSH public key(s) so you can log into this
  # machine (and so root authorizes the same key).
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOk8iAnIaa1deoc7jw8YACPNVka1ZFJxhnU4G74TmS+p"
  ];
in {
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

  # hostName is set per-host (see ./amd, ./intel).
  networking.networkmanager.enable = true;

  # Turn on flag for proprietary software
  nix = {
    nixPath = [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ];
    settings = {
      allowed-users = [ "${user}" ];
      trusted-users = [ "@admin" "${user}" ];
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
    # ── Desktop: KDE Plasma 6 on Wayland via SDDM ──────────────────────
    # xserver provides Xwayland + xkb config even on a Wayland session.
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        options = "ctrl:nocaps"; # Caps Lock -> Ctrl
      };
    };
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      defaultSession = "plasma";
    };
    desktopManager.plasma6.enable = true;

    # Better support for general peripherals
    libinput.enable = true;

    # Let's be able to SSH into this machine
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
      openssh.authorizedKeys.keys = sshKeys;
    };

    root = {
      openssh.authorizedKeys.keys = sshKeys;
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
  system.stateVersion = "25.11";
}
