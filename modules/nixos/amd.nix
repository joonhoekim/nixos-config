{ config, pkgs, ... }:

# Shared AMD Ryzen + Radeon (iGPU) layer. Vendor-common settings only —
# per-chassis quirks live in the host dirs (hosts/nixos/<hostname>/). mn56
# (7840HS) imports this; any future AMD host should too.
#
# CPU microcode (hardware.cpu.amd.updateMicrocode) and redistributable
# firmware are already switched on by the generated hardware-configuration.nix
# via not-detected.nix, so they are not repeated here.

{
  # amdgpu (RDNA3 / 780M) is fully covered by mesa — no extra driver package.
  # radeonsi also provides VAAPI (H.264/HEVC/AV1 decode), so nothing has to be
  # added to hardware.graphics.extraPackages here. Intel iGPUs are the contrast
  # worth remembering: i915/xe render fine on mesa alone, but VAAPI/QSV video
  # decode needs pkgs.intel-media-driver (iHD) added explicitly.
  #
  # If OpenCL (ROCm) is ever needed:
  #   hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr.icd ];
  # It is a heavy build — only enable it when something actually uses it.

  # NOTE: powerManagement.cpuFreqGovernor is intentionally NOT set. On Zen4 the
  # amd_pstate driver runs in EPP (active) mode and ignores generic cpufreq
  # governors; services.power-profiles-daemon (common.nix) drives the Energy
  # Performance Preference instead:
  #   powerprofilesctl set {power-saver|balanced|performance}
  # Check which driver is bound with:
  #   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver

  environment.systemPackages = with pkgs; [
    # AMD-specific inspection (the vendor-neutral set is in
    # modules/nixos/packages.nix).
    radeontop          # iGPU utilization
    nvtopPackages.amd  # GPU monitor
    # cpupower + turbostat, taken from the running kernel's package set so it
    # matches boot.kernelPackages (linuxPackages_latest).
    config.boot.kernelPackages.cpupower
  ];
}
