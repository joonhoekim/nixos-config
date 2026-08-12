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
  # Check what actually got picked up with `vainfo` (pkgs.libva-utils, in the
  # package list below). On evo-t1 that reports iHD 26.1.6 against VA-API 1.24
  # and a full Xe-LPG profile list — AV1/HEVC/VP9/H.264 decode *and* encode —
  # so these two lines are doing the work they claim to.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  # Proactive thermal management. thermald prefers the firmware's own DPTF
  # tables and falls back to its packaged thermal-conf.xml when there are none
  # — which is what happens on evo-t1 (the log line naming the config file is
  # the tell, and `--adaptive` found no GDDV to read). Useful either way, and it
  # matters most in small/passive chassis, which is what both Intel machines
  # here are.
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
    nvtopPackages.intel # GPU monitor for the Intel iGPU
    libva-utils         # `vainfo` — the check the VAAPI note above asks for

    # i7z used to sit here for "CPU C-state / turbo detail" and has been
    # dropped. It is a 2020 release that dispatches off a hardcoded CPU table,
    # so on Arrow Lake-H it prints
    #   Unknown processor, not exactly based on Nehalem, Sandy bridge or Ivy
    #   Bridge
    # and then shows a single made-up core with no frequency and no C-state
    # residency — worse than nothing, because it still exits 0.
    #
    # cpupower + turbostat replace it, taken from the running kernel's package
    # set so they match boot.kernelPackages (linuxPackages_latest in
    # common.nix) rather than the default one. That versioning is the point:
    # turbostat is built from the same tree as the kernel that boots, so it
    # always knows the topology that kernel knows — including the P/E/LPE mix
    # a hybrid part has and i7z never learned.
    #   sudo turbostat --quiet --show PkgWatt,Busy%,Bzy_MHz,PkgTmp
    config.boot.kernelPackages.cpupower
    config.boot.kernelPackages.turbostat
  ];
}
