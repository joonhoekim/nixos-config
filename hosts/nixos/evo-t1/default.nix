{ ... }:

# GMKtec EVO-T1 (NucBox_EVO-T1, board V1.1, firmware V2.03 2025-12-16) —
# Core Ultra 9 285H (Arrow Lake-H): 16 cores / 16 threads, no SMT, 400 MHz to
# 5.4 GHz, Arc 140T iGPU, NPU 4. 64 GB as 2× 32 GB DDR5-5600. Actively cooled
# mini PC, always on AC.
#
# Vendor-common Intel CPU/GPU config lives in modules/nixos/intel.nix; only
# this chassis' own bits belong here. The first pass of this file was written
# before the machine existed and marked what to check on first boot; what
# follows is what those checks actually returned, so it is a record rather
# than a plan. Where the guess was wrong, the note says so — the wrong guess
# is the useful part.
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

  # ── GPU: i915, and that is the designed path ─────────────────────────
  # 00:02.0 is [8086:7d51], which lspci calls "Arrow Lake-P [Arc Pro
  # 130T/140T]". Both i915 and xe list it as a supported module and **i915 is
  # the one that binds**. That is not xe losing a race: i915 identifies the
  # part as `meteorlake`, display version 14.00 stepping D0, because Arrow
  # Lake-H reuses Meteor Lake's Xe-LPG graphics and display IP. xe takes over
  # from Lunar Lake (Xe2) on, which this is not.
  #
  # Everything the driver needs loaded on its own, no force_probe and no
  # firmware hand-holding:
  #   DMC  i915/mtl_dmc.bin v2.23        display power management
  #   GuC  i915/mtl_guc_70.bin 70.53.0   both GT0 and GT1, submission + SLPC + RC
  #   HuC  i915/mtl_huc_gsc.bin 8.5.4    "authenticated for all workloads"
  #   GSC  i915/mtl_gsc_1.bin r102.1.15.1926
  # The HuC line is the one worth caring about — it is what makes low-power
  # fixed-function video encode real rather than a fallback, and it only says
  # "for all workloads" after GSC finishes loading a second later. VT-d is
  # active for gfx access.
  #
  # VAAPI on top of that is confirmed working: iHD 26.1.6 / VA-API 1.24, with
  # AV1, HEVC (through 4:4:4 12-bit and SCC), VP9 and H.264 in both decode and
  # encode. See modules/nixos/intel.nix, which is what supplies the driver.
  #
  # Five outputs on card1 — DP-1, DP-2, DP-3, HDMI-A-1, HDMI-A-2 — of which
  # DP-1 is the one in use.
  #
  # `xe.force_probe=` would swap drivers. There is no reason to: it would
  # trade a mature driver for a newer one on hardware the newer one does not
  # target, and the feature set above is already complete.

  # ── NPU ───────────────────────────────────────────────────────────────
  # 00:0b.0 [8086:7d1d], "Intel AI Boost". nixos-generate-config detected it
  # and wrote `hardware.cpu.intel.npu.enable = true` into
  # ./hardware-configuration.nix itself, which is more than the usual
  # disks-and-microcode scan does, so it is easy to miss when skimming that
  # file. It is not a no-op: the nixpkgs module behind it
  # (nixos/modules/hardware/cpu/intel-npu.nix) adds intel-npu-driver's
  # firmware, puts the driver in hardware.graphics.extraPackages next to the
  # two from ../../modules/nixos/intel.nix, and installs level-zero plus the
  # driver's validation tools system-wide.
  #
  # The kernel half works out of the box: intel_vpu binds, /dev/accel/accel0
  # appears (0666 root:render, so no group membership is needed), firmware
  # intel/vpu/vpu_37xx_v1.bin loads and the scheduler comes up in HW mode.
  # `npu-kmd-test` — on PATH from the validation package — passes 91 of 96,
  # skipping only the five reset-engine cases.
  # /sys/class/accel/accel0/device/npu_busy_time_us is the cheap "is anything
  # using it" counter.
  #
  # Left enabled — this is generated output and the repo treats that file as
  # authoritative — but nothing here uses the NPU yet.

  # ── Networking: both guesses in the first draft were wrong ───────────
  # Wi-Fi is **not** Wi-Fi 7. 00:14.3 is the Arrow Lake CNVi MAC [8086:7740],
  # but CNVi splits the MAC from the RF module and the module fitted here is a
  # Harrison Peak (RF HR B3, rfid=0x10a100), so iwlwifi resolves the pair to
  # "Intel(R) Wi-Fi 6 AX201 160MHz" and loads bz-b0-hr-b0-100.ucode. It
  # associates fine; enableRedistributableFirmware (via not-detected.nix)
  # covers the blob. Bluetooth is the same module's, on USB as 8087:0026, and
  # bluetooth.service is up. The lesson for the next machine: a new-generation
  # CNVi PCI ID says nothing about which Wi-Fi generation is actually
  # installed — only `dmesg | grep iwlwifi` does.
  #
  # A stray "uses wireless extensions which will stop working for Wi-Fi 7
  # hardware" warning shows up in dmesg from a Chromium thread. It is about
  # the ancient WEXT ioctls, not about this card, and is harmless here.
  #
  # Ethernet is **not** Intel igc either. It is 2× Realtek RTL8125 2.5GbE
  # [10ec:8125 rev 05] at 2d:00.0 and 2e:00.0, driven by the in-tree r8169.
  # No firmware needed and nothing to configure, but it is worth knowing which
  # driver this is if a link ever goes flaky: r8169 + RTL8125 has a history of
  # ASPM-related stalls, and `r8169.aspm=0` / disabling ASPM for those ports is
  # the first thing to try — that is a different playbook from igc's.
  #
  # Thunderbolt 4 — domain0 behind 00:0d.2. "thunderbolt" is already in
  # boot.initrd.availableKernelModules (the scan put it there), so anything
  # that ever has to boot off the TB port can. Device authorization is handled
  # by boltd, which is running — but nothing in this repo asks for it: it
  # comes from services.desktopManager.gnome (common.nix), which enables
  # services.hardware.bolt. If GNOME is ever dropped from common.nix, bolt has
  # to be enabled explicitly or TB devices stop being authorizable.
  # OCuLink is plain PCIe and has no OS-side switch.

  # ── Storage: two drives, not one ─────────────────────────────────────
  # The first draft of this file said "one NVMe". Both M.2 slots are
  # populated, with the same model in each — SOLIDIGM SSDPFKKW512H7, 512 GB:
  #
  #   nvme1n1  this system. p1 = 2 G ESP at /boot, p2 = 474.9 G ext4 "nixos"
  #            at /. 36 G used.
  #   nvme0n1  p1 = 16 M Microsoft reserved, p2 = 476.9 G exFAT "New Volume".
  #            Not mounted, not referenced by any fileSystems entry.
  #
  # Neither drive is new — nvme1 has 3,902 power-on hours and 22.2 TB written,
  # nvme0 has 2,522 hours and 11.0 TB. Both report percentage_used 1-2%, zero
  # warning and zero critical composite-temperature time, and idle at ~38 °C
  # composite in this actively cooled chassis (mn56's single NVMe idles at
  # ~64 °C in a passive one — same class of part, very different thermal
  # story).
  #
  # nvme0n1 is left alone — unmounted, in no fileSystems entry. It carries no
  # ESP either, so the "firmware may prefer the other disk's boot entry"
  # failure that galaxy-chromebook-1 keeps efibootmgr around for cannot happen
  # as things stand. That would change the moment anything writes an EFI System
  # Partition to it.

  # ── Swap ──────────────────────────────────────────────────────────────
  # No swap partition on either drive: zram alone is the whole swap story
  # here, and at 50% of 64 GB (common.nix) that is 31 GB of compressed swap
  # with no disk backstop behind it — a different shape from the other two
  # hosts, not an oversight. It also means no hibernate; see the sleep note.

  # ── Sleep: untested, but this chassis has options mn56 never had ─────
  # The firmware advertises "ACPI: PM: (supports S0 S3 S4 S5)". That S3 is the
  # whole difference from mn56, whose firmware offers S0 S4 S5 only — so when
  # s2idle broke there, there was nothing to fall back to and every sleep
  # target had to be masked (see ./mn56 for both postmortems). Here
  # /sys/power/mem_sleep reads
  #
  #   [s2idle] deep
  #
  # so if s2idle turns out to misbehave on this box too, the fix is one kernel
  # parameter rather than giving up on suspend:
  #
  #   boot.kernelParams = [ "mem_sleep_default=deep" ];
  #
  # Nothing is masked here, and nothing has been tested — suspend has not been
  # tried once. That is deliberate: mn56's masks are a per-chassis finding, not
  # a house rule, and copying them here would hide whichever behaviour this
  # machine actually has.
  #
  # S4 is advertised but unreachable regardless: hibernate needs a resume
  # device, there is no swap partition, and boot.resumeDevice points nowhere.

  # ── Power / thermals ─────────────────────────────────────────────────
  # Desktop box, no battery. intel_pstate is bound, scaling_governor reads
  # "powersave" (intel_pstate naming, not behaviour — see the note in
  # ../../modules/nixos/intel.nix) and the EPP sits at balance_performance.
  #
  # power-profiles-daemon comes up on `balanced`. Worth knowing what its
  # profiles can and cannot do here: there is no
  # /sys/firmware/acpi/platform_profile on this firmware, so `powerprofilesctl
  # list` shows PlatformDriver "placeholder" and every profile switch is EPP
  # and scaling only, with no firmware-side power limit change behind it. If
  # this ends up doing sustained work:
  #   powerprofilesctl set performance
  #
  # Idle thermals, for a baseline to compare against later: package 50 °C
  # against a 105 °C critical point, DDR5 SPD sensor 39.8 °C, both NVMe ~38 °C.
  # `sensors` also reports an acpitz_0 zone at -273.3 °C — an unpopulated ACPI
  # thermal zone reading absolute zero, i.e. noise to ignore, not a broken
  # sensor.
  #
  # dmesg is otherwise clean. The only warnings are two "resource sanity
  # check ... mapping multiple BARs" lines from igen6_probe as the igen6_edac
  # memory-error driver claims the platform, which is cosmetic and expected on
  # these SoCs.

  # ── Drive health monitoring ──────────────────────────────────────────
  # The first draft left this off until the drives were confirmed to answer
  # SMART, because smartd with autodetect and no supported device fails to
  # start rather than staying quiet. They do: `smartctl --scan` finds both as
  # NVMe devices and a full `-a` reads back on each. So it goes on, same as
  # ./mn56.
  #
  # modules/nixos/packages.nix already ships smartmontools, but that is only
  # the `smartctl` CLI — it tells you nothing unless you remember to go look.
  # smartd polls in the background and shouts (wall + syslog) when an
  # attribute crosses a threshold, which is the half that was missing. With
  # two used drives at 2,500-3,900 hours each, catching a trend is exactly
  # what this is for.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # ── Not enabled, on purpose ──────────────────────────────────────────
  # modules/nixos/nginx.nix — mn56-only work setup, not wanted here.
  #
  # services.fwupd — the firmware is V2.03 from 2025-12-16 and no other host
  # here runs fwupd, so there is no precedent to follow. Whether GMKtec
  # publishes to LVFS at all is unverified, and it cannot be checked without
  # the daemon running. If it is ever turned on, the components most likely to
  # have updates are the Solidigm SSDs and the UEFI dbx, not the board.
  #
  # OpenCL / GPU compute — hardware.graphics.extraPackages could take
  # pkgs.intel-compute-runtime (NEO) to expose OpenCL and Level Zero on the
  # iGPU. level-zero itself is already installed as a side effect of the NPU
  # module above, so the runtime is the only missing piece. Left out because
  # nothing on this machine asks for it yet.
}
