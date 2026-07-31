{ user, ... }:

# Galaxy Chromebook 1 — Intel, fanless 2-in-1 with a Wacom stylus and a
# touchscreen. Ported from the standalone config this machine ran before it
# joined this repo.
#
# Unlike ./amd and ./intel this host is ALREADY INSTALLED, so its
# hardware-configuration.nix is the real generated one (not a placeholder)
# and its stateVersions are pinned to the release it was installed at.

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
