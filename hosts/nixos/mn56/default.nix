{ config, ... }:

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

  # ── Hibernate (suspend-to-disk) ──────────────────────────────────────
  # hardware-configuration.nix declares a 48G swap partition, ≥ the 48G of
  # installed RAM, so a full image always fits.
  #
  # This one option is the whole feature: it puts `resume=<dev>` on the kernel
  # command line (see nixos/modules/system/boot/systemd/initrd.nix), which
  # systemd-hibernate-resume in the initrd uses to restore the image, and which
  # the kernel *also* uses as the device to write the image to
  # (swsusp_resume_device). That second half matters here because common.nix
  # enables zramSwap: zram0 is an active swap area, and without an explicit
  # resume device the kernel would pick the first swap area it finds — possibly
  # RAM-backed zram, which loses the image on power-off. (systemd's own
  # hibernation path already skips zram, but the kernel's does not.)
  #
  # Same UUID as the swapDevices entry; keep the two in sync if the partition
  # is ever recreated.
  boot.resumeDevice = "/dev/disk/by-uuid/423f3ce2-ba0e-4ee3-a8a5-7868532f2201";

  # GNOME has no hibernate entry in its power menu (upstream dropped it), so
  # this is driven from the shell: `systemctl hibernate`. logind's polkit
  # default already allows it for the active local session, no sudo needed.

  # ── Any suspend → straight to disk ───────────────────────────────────
  # This box only supports s2idle (dmesg: "ACPI: PM: (supports S0 S4 S5)" —
  # no S3), and s2idle on this chassis is not trustworthy. On 2026-08-03 a
  # suspend entered s2idle and never came out: the journal stops dead at
  # "PM: suspend entry (s2idle)" with no matching exit, no hibernation image
  # was ever written (next boot: "PM: Image not found (code -22)", and no
  # HibernateLocation EFI variable), and the AX200 came back wedged —
  # "CSR_RESET = 0x10" then "probe with driver iwlwifi failed with error -110"
  # across six warm reboots. Only a full power-off cleared the card, because a
  # warm reset leaves the M.2 rails up.
  #
  # This machine is only ever asked to hibernate anyway, once by hand at the
  # end of the day. So skip s2idle entirely rather than transit through it:
  # the earlier suspend-then-hibernate setup suspended first and armed an RTC
  # alarm to hibernate 3h later, which meant the fragile leg ran unattended.
  # Going straight to disk removes that leg, and HibernateDelaySec with it —
  # it governs nothing once suspend-then-hibernate is out of the picture.
  #
  # The override is what keeps the s2idle path unreachable. The session here is
  # niri + DankMaterialShell, and dms' power menu "Suspend" runs `systemctl
  # suspend`: Services/SessionService.qml picks systemctl over loginctl in
  # powerManagerCommand(), and customPowerActionSuspend is empty. That pulls in
  # suspend.target, which is Requires=systemd-suspend.service. The idle timeout
  # lands on the same unit — IdleService calls suspendWithBehavior() with
  # acSuspendBehavior, and that setting is Suspend (0). The upstream suspend and
  # hibernate units differ solely in the systemd-sleep verb, so swapping the
  # verb here makes the menu item, the suspend key and `systemctl suspend` all
  # hibernate instead. NixOS emits this as a drop-in over the upstream unit; the
  # empty first element resets its ExecStart.
  #
  # What this does NOT cover: systemd-suspend-then-hibernate.service is its own
  # unit and is left untouched. Setting dms' suspend behaviour to
  # SuspendThenHibernate (2) would run `systemctl suspend-then-hibernate` and
  # reach s2idle again, so leave acSuspendBehavior alone.
  systemd.services.systemd-suspend.serviceConfig.ExecStart = [
    ""
    "${config.systemd.package}/lib/systemd/systemd-sleep hibernate"
  ];

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
