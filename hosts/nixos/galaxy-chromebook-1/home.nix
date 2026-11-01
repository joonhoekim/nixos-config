{ ... }:

{
  # Auto-appears on text focus; this 2-in-1 is often used without its keyboard.
  dconf.settings."org/gnome/desktop/a11y/applications" = {
    screen-keyboard-enabled = true;
  };

  # Read by Brave's launcher at start: restart Brave, no rebuild. --enable-wayland-ime
  # is what makes fcitx5 Hangul work inside Brave.
  home.file.".config/brave-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=UseOzonePlatform,WaylandWindowDecorations
    --enable-wayland-ime
    --top-chrome-touch-ui=enabled
  '';
}
