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
    ./hardware-configuration.nix
    ./hardware.nix
  ];

  networking.hostName = "galaxy-chromebook-1";

  # Caps Lock -> Ctrl. This machine only: the Chromebook chassis has no Ctrl
  # where the fingers expect one. It used to sit in ../common.nix and applied
  # to every host, which was never the intent.
  #
  # This knob covers X11 sessions and (with console.useXkbConfig) the TTY. It
  # does NOT reach a GNOME Wayland session — mutter builds its keymap from
  # org.gnome.desktop.input-sources, so the dconf half in ./home.nix is what
  # actually does the work there. Both are kept: they cover different sessions,
  # and this host is expected to see more than one.
  services.xserver.xkb.options = "ctrl:nocaps";

  # This machine's EFI NVRAM carries more than one "Linux Boot Manager" entry,
  # left over from an install on a partition that no longer exists. The
  # firmware tries the dead one first, prints
  #
  #   Booting from 'Linux Boot Manager' failed: Not Found
  #
  # and only then falls through to the live entry — so it boots fine, just
  # noisily. `bootctl status` shows which entries exist but cannot remove one;
  # efibootmgr is the tool that can (`efibootmgr -b <ID> -B`).
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
