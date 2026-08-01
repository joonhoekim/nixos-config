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

  # ── Suspend → hibernate after 3h ─────────────────────────────────────
  # This box only supports s2idle (dmesg: "ACPI: PM: (supports S0 S4 S5)" —
  # no S3), so a plain suspend keeps drawing real power. Hand the session over
  # to disk once it is clearly not coming back soon.
  #
  # systemd-sleep's suspend-then-hibernate suspends, arms the RTC wake alarm
  # (/sys/class/rtc/rtc0/wakealarm exists here), wakes on expiry and hibernates.
  # With no battery in the chassis the delay is the only trigger, so
  # HibernateDelaySec is the whole policy (HibernateOnACPower only applies to
  # battery systems, and SuspendEstimationSec is never reached).
  systemd.sleep.settings.Sleep.HibernateDelaySec = "3h";

  # …and route *every* plain suspend into that path. GNOME's power menu calls
  # logind's SuspendWithFlags (checked: gnome-session links only that symbol,
  # not SuspendThenHibernate), which starts systemd-suspend.service, and
  # nothing in logind.conf remaps it — SleepOperation= only governs the "sleep"
  # action, which GNOME never asks for. The two upstream units differ solely in
  # the systemd-sleep verb, so swapping the verb here makes the menu item, the
  # suspend key and `systemctl suspend` all behave as suspend-then-hibernate.
  # NixOS emits this as a drop-in over the upstream unit; the empty first
  # element resets its ExecStart.
  systemd.services.systemd-suspend.serviceConfig.ExecStart = [
    ""
    "${config.systemd.package}/lib/systemd/systemd-sleep suspend-then-hibernate"
  ];

  # Chassis quirks go here. Nothing is guessed before the machine has actually
  # booted — wireless firmware (MT7922 / RTL8852BE, depending on the unit) is
  # already covered by enableRedistributableFirmware, which the generated
  # hardware-configuration.nix pulls in via not-detected.nix.
}
