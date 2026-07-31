{ ... }:

# Home-manager additions for this machine only. Merged with the base config in
# modules/nixos/home-manager.nix by ./default.nix.

{
  # GNOME on-screen keyboard — auto-appears when a text field is focused.
  # This is a 2-in-1 touch device and gets used keyboard-less often.
  dconf.settings."org/gnome/desktop/a11y/applications" = {
    screen-keyboard-enabled = true;
  };

  # Caps Lock -> Ctrl for the GNOME Wayland session. mutter derives its keymap
  # from these dconf keys, not from services.xserver.xkb — that option (set in
  # ./default.nix for X11/TTY) is silently ignored on Wayland. Verified on mn56:
  # xkb.options said ctrl:nocaps while `xkb-options` here was empty and the
  # remap was simply not happening.
  dconf.settings."org/gnome/desktop/input-sources" = {
    xkb-options = [ "ctrl:nocaps" ];
  };

  # Brave flags — read by Brave's launcher on every start, so changing them
  # needs a restart of the browser but not a rebuild.
  # --enable-wayland-ime is what makes fcitx5 Hangul work inside Brave;
  # --top-chrome-touch-ui is specific to this touch machine.
  home.file.".config/brave-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=UseOzonePlatform,WaylandWindowDecorations
    --enable-wayland-ime
    --top-chrome-touch-ui=enabled
  '';
}
