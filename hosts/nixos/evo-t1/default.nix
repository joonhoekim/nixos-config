{ ... }:

# GMKtec EVO-T1 — Core Ultra 9 285H (Arrow Lake-H, Arc 140T iGPU, NPU 4),
# 64 GB RAM. Actively cooled mini PC, always on AC.
#
# Vendor-common Intel CPU/GPU config lives in modules/nixos/intel.nix; only
# this chassis' own bits belong here. Nothing below is guessed ahead of the
# machine — the notes mark what to check on the first boot, and a quirk only
# becomes a setting once it has actually shown up.
{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "evo-t1";

  # Installed from a 26.05 installer (confirmed with `nixos-version` on the
  # install media), so it stays at 26.05. stateVersion is "the release this
  # machine's state was created at", not "the channel it tracks" — the flake
  # still follows nixos-unstable, so packages keep moving regardless.
  # common.nix's mkDefault 26.11 is deliberately not what a fresh install
  # should get.
  system.stateVersion = "26.05";

  # home.stateVersion is deliberately left at the 26.11 default
  # (modules/nixos/home-manager.nix): no home-manager state exists on this
  # machine yet, so the first activation should get current defaults rather
  # than 26.05-era compatibility shims. The two knobs are independent.

  # ── What to look at after the first boot ─────────────────────────────
  # Arrow Lake-H is recent enough that all of this hangs on the kernel being
  # new; common.nix already pins linuxPackages_latest, which is the whole
  # reason nothing needs a force_probe here.
  #
  # GPU — Xe-LPG+ (Arc 140T). Two drivers can claim it: i915, which has
  # carried Meteor/Arrow Lake since 6.8, and xe, the newer one that takes
  # Lunar Lake (Xe2) and later by default. Whichever bound is in
  #   lspci -k -s 00:02.0        # "Kernel driver in use: i915" or "xe"
  # and both render on mesa alone. Only force the other one (`i915.force_probe=`
  # / `xe.force_probe=`) if something is actually broken — the swap changes
  # which driver's bugs you get, not the feature set.
  #
  # NPU — "Intel AI Boost", the intel_vpu module. It probes on its own; there
  # is nothing to enable here. Userspace (intel-npu-driver / OpenVINO) is not
  # installed because nothing on this machine uses it yet.
  #
  # Wi-Fi 7 / Bluetooth — an Intel BE-series card on iwlwifi. Firmware comes
  # from enableRedistributableFirmware, which the generated
  # hardware-configuration.nix pulls in via not-detected.nix, so it should
  # just work. `dmesg | grep iwlwifi` on the first boot is worth one look:
  # a too-old firmware blob for a too-new card is the failure mode, and it
  # shows up there rather than as a missing interface.
  #
  # Ethernet — 2× 2.5 GbE, driven by igc. In-tree, no firmware needed.
  #
  # Thunderbolt 4 / OCuLink — the tb port needs `boot.initrd.availableKernelModules`
  # to carry "thunderbolt" if anything ever has to boot off it;
  # nixos-generate-config normally writes that itself. OCuLink is plain PCIe
  # and has no OS-side switch.

  # ── Storage / swap ───────────────────────────────────────────────────
  # One NVMe, ESP on nvme1n1p1 and a single ext4 root on nvme1n1p2. No swap
  # partition: zram alone is the whole swap story here, and at 50% of 64 GB
  # (common.nix) that is 32 GB of compressed swap with no disk backstop
  # behind it — which is a different shape from the other two hosts, not an
  # oversight. It also means no hibernate, there being no resume device to
  # point boot.resumeDevice at. No loss: the one machine here that tried S4
  # corrupted a kernel doing it (see ./mn56).
  #
  # The chassis has a second M.2 slot. If a drive in it ever carries its own
  # ESP, the firmware may well prefer that one — galaxy-chromebook-1 keeps
  # efibootmgr installed for exactly that class of problem, and the same
  # `efibootmgr -b <ID> -B` applies here.

  # ── Power ────────────────────────────────────────────────────────────
  # Desktop box, no battery. power-profiles-daemon (common.nix) comes up on
  # `balanced`; if this ends up doing sustained work, pin it:
  #   powerprofilesctl set performance
  #
  # Sleep is left alone on purpose. mn56 masks every sleep target because
  # *that* chassis' s2idle and S4 both proved broken (see ./mn56 for the two
  # postmortems); that is a per-chassis finding, not a house rule, and this
  # machine has not been tried yet.

  # ── Not enabled yet, on purpose ──────────────────────────────────────
  # services.smartd — mn56 runs it, and this box has NVMe too, so it is the
  # obvious next addition. It is left off until the drive is confirmed to
  # answer SMART (`smartctl -a /dev/nvme0`, smartmontools is already in
  # modules/nixos/packages.nix), because smartd with autodetect and no
  # supported device fails to start rather than staying quiet.
  #
  # modules/nixos/nginx.nix — mn56-only work setup, not wanted here.
}
