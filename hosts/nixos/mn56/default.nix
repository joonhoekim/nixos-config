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

  # Chassis quirks go here. Nothing is guessed before the machine has actually
  # booted — wireless firmware (MT7922 / RTL8852BE, depending on the unit) is
  # already covered by enableRedistributableFirmware, which the generated
  # hardware-configuration.nix pulls in via not-detected.nix.
}
