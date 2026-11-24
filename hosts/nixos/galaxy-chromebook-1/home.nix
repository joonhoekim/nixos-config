{ ... }:

{
  # Read by Brave's launcher at start: restart Brave, no rebuild. --enable-wayland-ime
  # is what lets the compositor's input method (Hangul) reach Brave.
  home.file.".config/brave-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=UseOzonePlatform,WaylandWindowDecorations
    --enable-wayland-ime
    --top-chrome-touch-ui=enabled
  '';
}
