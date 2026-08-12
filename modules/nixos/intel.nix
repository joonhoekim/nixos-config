{ config, pkgs, ... }:

# Shared Intel CPU + iGPU (i915 / xe) layer. Vendor-common settings only —
# per-chassis quirks live in the host dirs (hosts/nixos/<hostname>/). evo-t1
# (Core Ultra 9 285H) and galaxy-chromebook-1 (UHD 620) both import this; the
# amd.nix next to it is the same idea for the Ryzen side.
#
# CPU microcode (hardware.cpu.intel.updateMicrocode) and redistributable
# firmware are already switched on by the generated hardware-configuration.nix
# via not-detected.nix, so they are not repeated here.

{
  # Rendering works on mesa alone, but *video* does not — and that is the one
  # place Intel differs from the AMD side, where radeonsi carries VAAPI with
  # it (see the same note in ./amd.nix, written from the other direction).
  #
  #   intel-media-driver  the iHD VAAPI driver (Broadwell and newer)
  #   vpl-gpu-rt          oneVPL runtime — the QSV path ffmpeg/OBS take on
  #                       Gen12+ (Tiger Lake onward). Harmless on older parts:
  #                       libvpl simply finds no matching implementation and
  #                       falls back to VAAPI.
  #
  # Check what actually got picked up with `vainfo` (pkgs.libva-utils).
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  # Proactive thermal management via the DPTF tables the firmware exposes.
  # It matters most in small/passive chassis, which is what both Intel
  # machines here are.
  services.thermald.enable = true;

  # NOTE: powerManagement.cpuFreqGovernor is intentionally NOT set. On Intel
  # CPUs the intel_pstate driver ignores generic cpufreq governors;
  # services.power-profiles-daemon (hosts/nixos/common.nix) drives the Energy
  # Performance Preference instead. `scaling_governor` always reads
  # "powersave" — that's intel_pstate naming, not the actual behavior. Switch
  # profiles from the shell or the tray:
  #   powerprofilesctl set {power-saver|balanced|performance}
  # Check which driver is bound with:
  #   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver

  environment.systemPackages = with pkgs; [
    # Intel-specific inspection (the vendor-neutral set is in ./packages.nix).
    intel-gpu-tools     # intel_gpu_top, ...
    i7z                 # Intel CPU C-state / turbo detail
    nvtopPackages.intel # GPU monitor for the Intel iGPU
    # cpupower, taken from the running kernel's package set so it matches
    # boot.kernelPackages (linuxPackages_latest in common.nix) rather than the
    # default one.
    config.boot.kernelPackages.cpupower
  ];
}
