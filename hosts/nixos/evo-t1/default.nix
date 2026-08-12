{ pkgs, ... }:

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

  # ── The monitor on DP-1: its speakers ────────────────────────────────
  # DP-1 carries an HCS 40LGD5K (5120x2160, over USB-C DP Alt Mode) and that
  # panel has speakers. The kernel sees them: /proc/asound/card0/eld#2.12 reads
  # monitor_present 1, eld_valid 1, monitor_name 40LGD5K, connection_type
  # DisplayPort, speakers FL/FR, one LPCM SAD at 2ch. PipeWire agrees — it
  # lists the matching port hdmi-output-0 as "available" with
  # device.product.name "40LGD5K". They still never appeared as a sink.
  #
  # The reason is that both codecs on this machine — the Senarytech SN6186 that
  # drives the analog jacks and the Meteor Lake HDMI codec that drives the
  # display — sit behind one ACP card, alsa_card.pci-0000_00_1f.3, and ACP
  # profiles are mutually exclusive. WirePlumber picks by profile priority and
  # analog duplex outranks HDMI (6565 against 5965), which does not leave the
  # HDMI sink idle, it stops it existing. So "NixOS does not recognise the
  # monitor's speakers" was never true; the sink was outvoted before it was
  # created.
  #
  # device.profile.priority.rules is the hook WirePlumber provides for exactly
  # this (scripts/device/find-preferred-profile.lua). It runs ahead of the
  # priority-based find-best-profile and names a profile outright.
  #
  # Two things it deliberately does not do, both worth knowing before this
  # looks broken:
  #
  #   It does not beat the state file. Of the three selection hooks,
  #   find-stored-profile runs *first*, so whatever
  #   ~/.local/state/wireplumber/default-profile holds for this card wins over
  #   the rule below. That is the right shape — a profile chosen by hand in a
  #   UI is a decision and should stick — but it means an entry left there by
  #   an earlier choice has to be removed once before this rule is what is
  #   actually in force.
  #
  #   It does not fall back. find-preferred-profile matches on profile name
  #   only and never consults availability (find-best-profile is the hook that
  #   checks), so with the monitor unplugged the card stays on the HDMI profile
  #   rather than dropping to analog. That is acceptable here and not
  #   elsewhere: on this box the 3.5 mm jack has nothing in it — lineout,
  #   headphones and both mics all report "not available" — and the everyday
  #   sink is a HIFIMAN EF400 USB DAC, which is its own card and untouched by
  #   any of this. The analog half of this codec is carrying nothing.
  services.pipewire.wireplumber.extraConfig."51-hdmi-audio-preference" = {
    "device.profile.priority.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_00_1f.3"; } ];
        actions.update-props.priorities = [
          "output:hdmi-stereo+input:analog-stereo"
        ];
      }
    ];
  };

  # ── The monitor on DP-1: brightness, and its USB hub ─────────────────
  # Both were investigated alongside the speakers. Neither needs anything on
  # this host, but "nothing to do" is the kind of answer that gets re-derived
  # from scratch a year later, so the findings stay.
  #
  # Brightness works over DDC/CI, and needs nothing on this host — but it was
  # dead for a while for a reason no amount of looking at this machine would
  # ever have found, so the route matters more than the answer.
  #
  # The mechanics first. There is no /sys/class/backlight, which is correct for
  # an external panel: the path is I2C over the DP AUX channel. /dev/i2c-10
  # ("AUX USBC1/DDI TC1/PHY TC1", the AUX line of this very connector) answers
  # on DDC address 0x37, the panel reports MCCS 2.1 on an Mstar controller, and
  # VCP 0x10 is in its capabilities string. DMS finds it by itself — `dms ipc
  # call brightness list` shows `ddc:i2c-10 (ddc)` — through a DDC backend
  # compiled into the dms binary, so ddcutil is not needed for the shell to
  # drive it (it is still the tool to debug with, and modules/nixos/packages.nix
  # ships it). Permissions come free as well: programs.dms-shell turns on
  # hardware.i2c, whose udev rule tags /dev/i2c-* with uaccess, so the seat
  # user gets an ACL and no i2c group membership is needed.
  #
  # ── What was actually wrong, in the order it was found ───────────────
  # Two separate faults, and the first one hid nothing — it just wasted the
  # search.
  #
  #   1. The keybind called DMS with the wrong number of arguments and failed
  #      silently. Real bug, fixed, and not host-specific — see
  #      ../../../modules/nixos/hyprland/rice/hyprland.lua.
  #
  #   2. The monitor's own OSD had HDR set to Auto, and in that mode the panel
  #      ignores manual brightness. DDC was working the whole time: writes were
  #      acknowledged and read back correctly. The backlight simply did not
  #      move, because the monitor had taken brightness away from itself.
  #      Turning HDR off in the OSD fixed it. Nothing on this machine was ever
  #      set to HDR — Hyprland reports colorManagementPreset srgb — so the
  #      state was invisible from the OS side in both directions.
  #
  # The wrong turn in between is the part worth keeping. `setvcp 10 60`
  # followed by `getvcp 10` returning 60 was taken as proof that brightness
  # control worked. It is not: it proves the monitor stored the value, and
  # says nothing about whether it acted on it. This panel will happily lie in
  # the same register — it answers 0x60 (input source) with "S-Video-1" while
  # connected over DisplayPort, and answers 0x13 (backlight control), which its
  # own capabilities string does not list, with a current value larger than the
  # maximum it reports in the same reply, refusing writes with DDCRC_VERIFY.
  #
  # apps/ddc-probe exists because of that. It holds each changed value on
  # screen while it asks whether anything moved, then restores. Only an eye
  # settles this question; use it before believing any DDC claim, this comment
  # included.
  #
  # So: if brightness ever appears dead again, check the monitor's OSD for HDR
  # / DCR / dynamic contrast / eco before suspecting anything in this repo.
  #
  # The monitor's USB hub works, and is USB 2.0 only for a reason that cannot
  # be configured away. It enumerates as 3-1, a 4-port GenesysLogic hub, on a
  # root port whose connect_type is "hotplug" — the soldered Bluetooth radio,
  # for contrast, sits on a "hardwired" one — and reports bMaxPower 0mA, i.e.
  # self-powered off the monitor. Both USB3 root hubs are empty, and that is
  # the DP Alt Mode trade rather than a fault: DP-1 is linked at four lanes of
  # HBR3 (i915_dp_force_lane_count reads 4*), this panel does not do DSC
  # (DSC_Sink_Support: no), and 5120x2160@60 undsc'd needs roughly 19.9 Gbit/s,
  # which two lanes cannot carry at about 13 Gbit/s usable. Four DP lanes on a
  # USB-C connector leave only USB 2.0 beside them. Keyboards, mice, headsets
  # and webcams are fine on that hub; an external SSD wants a port on the box.

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
  # The *userspace* half did not work, and that is the interesting part —
  # see the level-zero note below.

  # ── Making the NPU actually reachable ────────────────────────────────
  # `hardware.cpu.intel.npu.enable` puts intel-npu-driver into
  # hardware.graphics.extraPackages, which lands libze_intel_npu.so.1 in
  # /run/opengl-driver/lib. That is where every other graphics loader here
  # looks — and the Level Zero loader is the one that does not. It dlopens
  # driver libraries by bare soname and relies on the ordinary dynamic linker
  # search path, which on NixOS never contains /run/opengl-driver/lib. So
  # zeInitDrivers() returned ZE_RESULT_ERROR_UNINITIALIZED, npu-umd-test
  # failed in global setup before running a single test, and OpenVINO listed
  # only ['CPU'] — with the NPU plugin loaded and reporting "No available
  # devices" from inside itself, which is what makes this look like missing
  # hardware rather than a missing path.
  #
  # ZE_ENABLE_ALT_DRIVERS names driver libraries explicitly and is read by the
  # loader before it goes looking, so it fixes this without the collateral
  # damage of putting /run/opengl-driver/lib on a global LD_LIBRARY_PATH —
  # that would shadow mesa, libgbm and friends for every process on the box.
  # With it set, npu-umd-test's Driver suite passes and OpenVINO enumerates
  # the NPU.
  #
  # Two things to know about this variable. It *replaces* the loader's default
  # driver set rather than adding to it, so anything else that ever ships a
  # Level Zero driver has to be appended here by hand. And entries that do not
  # exist are skipped quietly (verified), so it is safe to list a path
  # speculatively.
  #
  # sessionVariables rather than environment.variables: this has to reach GUI
  # applications too, not just interactive shells.
  #
  # nixpkgs sets this nowhere, so it is not something the NPU module forgot to
  # turn on — the module has no notion of it at all.
  environment.sessionVariables.ZE_ENABLE_ALT_DRIVERS =
    "/run/opengl-driver/lib/libze_intel_npu.so.1";

  # ── How far the NPU actually goes today ──────────────────────────────
  # With the above in place the whole Level Zero stack works: npu-umd-test
  # runs 220 tests and passes 157, skipping 62 only because no model config
  # file was handed to it, and its one "failure" is the check that says so.
  # OpenVINO enumerates the device as "Intel(R) AI Boost".
  #
  # Compiling a model for it does NOT work, and will not until nixpkgs
  # changes. Ask OpenVINO to compile even a two-op graph for NPU and it dies
  # with
  #   Level0 pfnCreate2 result: ZE_RESULT_ERROR_UNSUPPORTED_FEATURE
  # from ze_graph_ext_wrappers.cpp. That is not a hardware or a firmware
  # limit. libze_intel_npu.so reaches its compiler by
  # dlopen("libnpu_driver_compiler.so") — the "Compiler in Driver" — and
  # nixpkgs' intel-npu-driver never builds it: the derivation installs exactly
  # three cmake components (level-zero-npu, validation-npu, fw-npu) and the
  # compiler is not among them. Nothing in /nix/store has that file, and the
  # driver being 2.1 MB rather than the ~100 MB a compiler-carrying build
  # weighs is the other tell. The reason is presumably circular: the CiD is
  # itself built out of OpenVINO.
  #
  # So the honest state is: the device is reachable and programmable through
  # raw Level Zero, but the OpenVINO "load an ONNX/IR model and run it on NPU"
  # path is closed. Importing an already-compiled blob takes a different
  # driver entry point than the one that fails here and may well work — that
  # has not been tried, for lack of any way to produce a blob on this machine.
  #
  # Nothing to fix in this repo; it wants either a nixpkgs change or a
  # locally-packaged compiler. Left written down so the next attempt does not
  # start by suspecting the firmware.

  # OpenCL for the iGPU, which is what OpenVINO's GPU plugin talks to — the
  # same plugin was failing with "no supported devices found" for want of it.
  # Worth having next to the NPU: comparing NPU / GPU / CPU on the same model
  # is most of what a hobby project on this hardware is going to do.
  #
  # This is a host-level import, deliberately not in
  # ../../modules/nixos/intel.nix: intel-compute-runtime supports 12th Gen and
  # newer, so on galaxy-chromebook-1 (Kaby Lake UHD 620) it would be dead
  # weight that also imports as a supported configuration when it is not.
  #
  # Note it ships only the OpenCL ICD (lib/intel-opencl/libigdrcl.so), no
  # Level Zero GPU driver — hence nothing to add to ZE_ENABLE_ALT_DRIVERS
  # above for the GPU side.
  hardware.graphics.extraPackages = [ pkgs.intel-compute-runtime ];

  environment.systemPackages = [
    # OpenVINO runtime — CPU, GPU and NPU plugins in one package, plus
    # ov-compile_tool. CPU and GPU work from here directly; `nix develop .#npu`
    # is what to use for the NPU, because openvino's NPU plugin cannot find
    # libze_loader.so.1 without help. The why, and why the fix lives in a shell
    # rather than an overlay, is in flake.nix next to that shell.
    pkgs.openvino
  ];

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

  # ── Firmware updates ─────────────────────────────────────────────────
  # Off. It was turned on once to answer a question that cannot be answered
  # from the outside — fwupdmgr talks to the daemon over D-Bus, so with the
  # service off there is no device list at all — and the answer is below.
  # Turn it back on for a minute if this ever needs re-checking.
  #
  # The answer, as of 2026-08-13: fwupd enumerates 15 updatable devices and
  # LVFS carries firmware for exactly one of them — UEFI dbx. Not the board
  # (BIOS1 / Internal SPI Controller, AMI 5.32), not Intel ME 18.1.18.2635,
  # not either Solidigm SSD, not the Genesys Logic hub. So GMKtec publishes
  # nothing to LVFS and neither does Solidigm for this part; their updates,
  # if any, are vendor tools and a USB stick.
  #
  # The dbx offer is 20241101 -> 20260402, Microsoft's Secure Boot revocation
  # list. It is deliberately not applied: Secure Boot is *disabled* in this
  # firmware (`bootctl status`), and dbx is only ever consulted when it is on,
  # so installing it buys exactly nothing today while still being an NVRAM
  # write to a no-name board's firmware. It becomes worth doing the day
  # Secure Boot gets turned on — and at that point it should be applied
  # *before* anything starts depending on an older signed loader, which is the
  # usual way a dbx bump bricks a dual boot.
  #
  # With one un-wanted update as the entire yield, there is nothing left for
  # the daemon to do here, so it goes back off rather than idling and
  # refreshing metadata weekly for a vendor that publishes nothing.
  services.fwupd.enable = false;

  # ── Not enabled, on purpose ──────────────────────────────────────────
  # modules/nixos/nginx.nix — mn56-only work setup, not wanted here.
}
