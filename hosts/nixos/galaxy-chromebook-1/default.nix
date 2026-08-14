{ pkgs, user, ... }:

# Galaxy Chromebook 1 — Intel, fanless 2-in-1 with a Wacom stylus and a
# touchscreen. Ported from the standalone config this machine ran before it
# joined this repo.
#
# Its stateVersions are pinned to the release it was actually installed at
# (25.11), which is older than the repo default — see below.

{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
    ./hardware.nix
  ];

  networking.hostName = "galaxy-chromebook-1";

  # No navigation layer on this host, and nothing to configure for it. The
  # layer in modules/nixos/keyboard.nix hangs off held Caps Lock, and this
  # chassis has no Caps Lock key — that position is the Chromebook
  # launcher/search key, which is a modifier and cannot carry a layer. Space
  # could, but only with the timing guards a space trigger needs to stay out of
  # the way of typing, and this machine browses far more than it types.
  #
  # It also means the `ctrl:nocaps` this host used to set (and its GNOME dconf
  # twin in ./home.nix, both now removed) had no key to act on in the first
  # place.

  # This machine's EFI NVRAM has twice accumulated dead "Linux Boot Manager"
  # entries ahead of the live one in BootOrder — once pointing at a partition
  # that no longer exists, once with the partition fields zeroed out entirely.
  # The firmware tries them first, prints
  #
  #   Booting from 'Linux Boot Manager' failed: Not Found
  #
  # and only then falls through to the live entry. Both are cleared as of
  # 2026-08-14; what wrote the zeroed ones was never identified.
  #
  # The trap, if it comes back: `bootctl status` only lists entries whose
  # device path it can parse, so a broken entry is exactly the one it hides.
  # Read `efibootmgr -v` instead. It is also the only one of the two that can
  # remove an entry (`efibootmgr -b <ID> -B`).
  # See docs/postmortems/2026-08-14-galaxy-chromebook-1-efi-boot-entries.md.
  #
  # Kept installed rather than reached for with `nix run`: the situation it
  # diagnoses is a boot problem, and a machine that will not boot is a poor
  # place to be downloading packages.
  environment.systemPackages = [ pkgs.efibootmgr ];

  # Installed at 25.11 and stays there. stateVersion pins stateful-data
  # layouts, not the nixpkgs channel — the flake still tracks nixos-unstable,
  # so packages keep moving. common.nix sets 26.11 with mkDefault for hosts
  # that get installed fresh.
  system.stateVersion = "25.11";

  # Merges with the base home-manager config the flake wires up
  # (modules/nixos/home-manager.nix); ./home.nix adds this machine's bits.
  home-manager.users.${user} = {
    imports = [ ./home.nix ];
    home.stateVersion = "25.11";
  };
}
