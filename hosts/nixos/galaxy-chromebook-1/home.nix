{ ... }:

# Home-manager additions for this machine only. Merged with the base config in
# modules/nixos/home-manager.nix by ./default.nix.

{
  # GNOME on-screen keyboard — auto-appears when a text field is focused.
  # This is a 2-in-1 touch device and gets used keyboard-less often.
  dconf.settings."org/gnome/desktop/a11y/applications" = {
    screen-keyboard-enabled = true;
  };

  # Caps Lock -> Ctrl used to be set here as a GNOME dconf key, because mutter
  # derives its keymap from org.gnome.desktop.input-sources and ignores
  # services.xserver.xkb on Wayland. It is now a keyd remap in ./default.nix,
  # which covers every session including niri.

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
