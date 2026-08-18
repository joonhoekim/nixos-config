{ ... }:

# Firebat MN56 — Ryzen 7 7840HS (Phoenix, RDNA3 780M) mini PC.
#
# Vendor-common AMD CPU/GPU config lives in modules/nixos/amd.nix; only this
# chassis' own bits belong here. There is a second 7840HS machine, so anything
# that turns out to be shared should move up into amd.nix.
{
  imports = [
    ../common.nix
    ../../../modules/nixos/amd.nix
    # nginx reproducing the reverse proxy that fronts the work app's
    # closed-network dev/qa servers. Package and unit only — the config under
    # /etc/nginx is managed imperatively by that repo's own deploy script.
    # This is the only machine used for that work, so it is imported here
    # rather than from ../common.nix.
    ../../../modules/nixos/nginx.nix
    # libvirt/KVM for a Windows guest — the work app's 공동인증 signing runs in a
    # native Windows program, so that half of the flow cannot be exercised on
    # this host directly. Same reasoning as nginx.nix for living here: this is
    # the only machine that work happens on.
    ../../../modules/nixos/libvirt.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "mn56";

  # Installed from a 26.05 installer, so it stays at 26.05 — this is what
  # nixos-generate-config wrote, and stateVersion is "the release this
  # machine's state was created at", not "the channel it tracks". The flake
  # still follows nixos-unstable, so packages keep moving regardless.
  system.stateVersion = "26.05";

  # home.stateVersion is deliberately left at the 26.11 default
  # (modules/nixos/home-manager.nix): no home-manager state exists on this
  # machine yet, so the first activation should get current defaults rather
  # than 26.05-era compatibility shims. The two knobs are independent.

  # Desktop box: always on AC, no battery. power-profiles-daemon (common.nix)
  # comes up on `balanced`; switch profiles if this ever needs to stay pinned
  # to performance.

  # ── Sleep: re-enabled on the 2025-03-11 BIOS ─────────────────────────
  # Both sleep states were broken on the shipping BIOS (1.00, 2024-01-13
  # build) and every path into them was masked here 2026-08-11 → 2026-08-13.
  # After flashing BIOS build 2025-03-11 (docs/postmortems/
  # 2026-08-13-mn56-bios-update.md), s2idle passed two rtcwake cycles (90s
  # and 120s — clean entry/exit pairs, RTC wake on time, wifi intact, no
  # errors). The old failures only ever showed on long cycles though (a
  # 2min hibernate passed while a 13.4h one corrupted the kernel), so short
  # tests prove little: the masks are lifted for a real-world evaluation
  # instead of more synthetic ones. If sleep wedges again, re-add the five
  # target masks (this block's git history has them) and reopen the story
  # below.
  #
  # What was broken, for when it comes back:
  #
  # s2idle is the only suspend state the firmware offers (dmesg: "ACPI: PM:
  # (supports S0 S4 S5)" — no S3), and on 2026-08-03 a suspend entered it and
  # never came out: the journal stops dead at "PM: suspend entry (s2idle)"
  # with no matching exit, and the AX200 came back wedged — "CSR_RESET =
  # 0x10" then "probe with driver iwlwifi failed with error -110" across six
  # warm reboots. Only a full power-off cleared the card, because a warm reset
  # leaves the M.2 rails up.
  #
  # Hibernate (S4) was the workaround for that: a 48G swap partition, a
  # boot.resumeDevice pointing at it, and systemd-suspend's ExecStart swapped
  # to the hibernate verb so every caller went straight to disk instead of
  # transiting s2idle. It survived two cycles and then corrupted the kernel on
  # the way back. On 2026-08-11 09:04:59 the resume itself finished cleanly —
  # "Restarting tasks: Done", "SMU is resumed successfully!", both outputs
  # re-detected — and two seconds later the first GPU client to touch a buffer
  # that had been evicted for the snapshot hit
  #
  #   list_del corruption. prev->next should be ..., but was 0000000000000000
  #   kernel BUG at lib/list_debug.c:62!
  #     ttm_resource_fini / ttm_sys_man_free / ttm_resource_free
  #     amdgpu_bo_move / ttm_bo_validate / amdgpu_cs_ioctl
  #
  # — a TTM resource LRU node that did not survive S4. The task died holding
  # the buffer's lock ("exited with preempt_count 1"), so everything that
  # wanted it afterwards spun forever in native_queued_spin_lock_slowpath:
  # amdgpu's atomic commit worker (hence monitors stuck on a stale frame) and
  # Hyprland (hence dead input). Soft lockups piled up for 149s until the
  # power button. Kernel 7.1.5, GFX 11.0.1 / DCN 3.1.4 — a driver bug with no
  # config-side fix, and not deterministic either: the 2026-08-04 cycle (2min
  # under) came back fine, the 2026-08-10 one (13.4h under) did not.
  #
  # The 48G swap partition in hardware-configuration.nix was sized against
  # the installed RAM because it had to hold a hibernate image. With sleep
  # re-enabled that duty is back (suspend-then-hibernate is reachable again),
  # so resumeDevice is too: without it hibernate would write an image the
  # next boot never resumes from — every hibernate silently a data-losing
  # power cycle. Same UUID as the swapDevices entry.
  boot.resumeDevice = "/dev/disk/by-uuid/423f3ce2-ba0e-4ee3-a8a5-7868532f2201";

  # ── Warm reboot hangs before POST ────────────────────────────────────
  # `reboot` leaves this box dark maybe a third of the time: both monitors
  # stay asleep and nothing ever comes up. Three of the ~10 warm reboots on
  # record failed that way — 2026-08-04 09:20 (133s to the next boot),
  # 2026-08-05 12:49 (53min), 2026-08-10 09:03 (110s) — against a normal
  # shutdown→boot gap of 19-24s. Every recovery was a power-button hold.
  #
  # The failure is below Linux. Shutdown itself is clean each time — the
  # journal runs all the way through "Sending SIGTERM to remaining
  # processes..." with no amdgpu complaint — and the attempt that hangs leaves
  # *no* boot record at all: journalctl --list-boots skips straight from the
  # session that asked to reboot to the one after the power cycle. The kernel
  # never reaches journald, so it is the firmware that stops.
  #
  # The default reboot type here is ACPI (/sys/kernel/reboot/type), a write to
  # the ACPI reset register, and the BIOS is still the shipping image (1.00
  # 01/13/2024). `reboot=pci` takes the port-CF9 path instead, which pulls the
  # platform reset harder. Consistent with the s2idle note above: warm resets
  # on this chassis leave rails up and devices half-initialised.
  #
  # If it still hangs, try `reboot=bios` and then `reboot=efi` before assuming
  # this cannot be fixed from the OS side. Note also that systemd arms the
  # SP5100 TCO watchdog with a 10min timeout on the way down and cannot disarm
  # it ("watchdog did not stop!"), so waiting ~10min may reset the box on its
  # own instead of holding the power button.
  boot.kernelParams = [ "reboot=pci" ];

  # ── BIOS flashing kit (kept on purpose) ──────────────────────────────
  # The shipping BIOS (1.00, build 2024-01-13) is suspected in all three
  # firmware-level faults above. The vendor's last update
  # (_temp/AR6000-MI2_PHX_250311_Firebat_DIS_SEC, AMI $FID says build
  # 2025-03-11, project 1AZKH011 — the version *string* stays "1.00", tell
  # them apart by dmidecode's Release Date) ships a UEFI-shell flasher
  # alongside the Windows one, so no Windows is needed: this entry boots the
  # EDK2 shell from the systemd-boot menu, with AfuEfix64.efi and the .rom
  # copied onto the ESP next to it. flashrom cannot back up the current image
  # from Linux (SPI is unmapped on this platform), so the backup happens in
  # the shell right before flashing:
  #
  #   FS0:                                    (map -r if files aren't here)
  #   AfuEfix64.efi mn56-bios-backup.rom /O   (dump current image first)
  #   AfuEfix64.efi AR6000-MI2.rom /p /b /n /k /RLC:E /reboot
  #
  # /n rewrites NVRAM, so expect BIOS settings and UEFI boot entries to
  # reset; \EFI\BOOT\BOOTX64.EFI on the ESP still boots systemd-boot, and
  # `nixos-rebuild boot` re-registers the entry.
  #
  # The flash happened 2026-08-13 (docs/postmortems/2026-08-13-mn56-bios-
  # update.md) and this block was going to be dropped afterwards — kept
  # instead: the shell entry plus AfuEfix64.efi, AR6000-MI2.rom and
  # mn56-bios-backup.rom on the ESP cost ~96 MiB and one boot menu line, and
  # together they are a standing reflash/rollback path that needs no USB
  # stick and no network. The ESP copy of the old-BIOS backup also doubles
  # the _temp copy, which git does not carry.
  boot.loader.systemd-boot.edk2-uefi-shell.enable = true;

  # ── Drive health monitoring ──────────────────────────────────────────
  # modules/nixos/packages.nix already ships smartmontools, but that is only
  # the `smartctl` CLI — it tells you nothing unless you remember to go look.
  # smartd polls in the background and shouts (wall + syslog) when an
  # attribute crosses a threshold, which is the half that was missing.
  #
  # Worth having on this box specifically: the NVMe idles at ~64 °C in this
  # small passive chassis. Wear is still at percentage_used 0%, so this is
  # about catching a trend, not a current problem.
  #
  # Kept here rather than in ../common.nix on purpose: with autodetect and no
  # supported device, smartd fails to start, and galaxy-chromebook-1's storage
  # has not been checked for SMART support. Move it up once it has.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Chassis quirks go here. Nothing is guessed before the machine has actually
  # booted — wireless firmware (MT7922 / RTL8852BE, depending on the unit) is
  # already covered by enableRedistributableFirmware, which the generated
  # hardware-configuration.nix pulls in via not-detected.nix.
}
