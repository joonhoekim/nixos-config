# System-wide key remapping via keyd.
#
# keyd acts at the evdev level — below xkb — so one config covers niri/Wayland,
# Xwayland, GNOME and the TTY identically. That is the whole reason remaps live
# here instead of in `services.xserver.xkb.options`: niri builds its keymap from
# its own config (modules/nixos/niri/rice/config.kdl) and never reads the
# xserver options, and mutter builds its keymap from dconf. An xkb-level remap
# therefore reaches whichever session happens to honour it and no other.
#
# Two remaps:
#   - Right Alt -> Hangul (한/영), for fcitx5-hangul. See ./korean.nix.
#   - Caps Lock held -> a vim/neovim navigation layer.
#
# The layer is a port of the Karabiner-Elements config this repo ships for
# macOS — same trigger, same keys, same tap-vs-hold split. The full rationale
# and key table is in modules/darwin/config/karabiner/README.md; only the
# actions differ, because the Linux equivalents of the macOS editing keys are
# Ctrl-arrow for word motions, Home/End for line ends, and Ctrl-c/v/z rather
# than Cmd-c/v/z.
#
# Imported by hosts/nixos/common.nix.
{ ... }:

let
  # [nav] — a *plain* layer, not a modifier layer. Keys with no binding below
  # type their own letter while Caps Lock is held, which is what the macOS
  # config does. (Making this `[nav:C]` would turn unbound keys into Ctrl
  # combos instead — see ../../hosts/nixos/galaxy-chromebook-1 for a host that
  # wants that trade.)
  #
  # Shift is not bound here, so it passes through: Caps+Shift+j emits Shift-Down
  # and extends a selection, exactly like the macOS layer. Keys where Shift is
  # itself part of the command ($ { } G N X U) are in the composite layer below.
  nav = {
    # hjkl -> arrows
    h = "left";
    j = "down";
    k = "up";
    l = "right";

    # w/e -> word forward, b -> word back (Alt-arrow on macOS, Ctrl-arrow here)
    w = "C-right";
    e = "C-right";
    b = "C-left";

    "0" = "home"; # line start ($ = Shift-4 -> end, in [nav+shift])

    # No neovim counterpart — i is insert and m is mark, so both are free.
    # They stand in for Ctrl-b/Ctrl-u and Ctrl-f/Ctrl-d.
    i = "pageup";
    m = "pagedown";

    g = "C-home"; # gg -> document top (G -> bottom, in [nav+shift])

    slash = "C-f"; # / -> find
    n = "C-g"; # n -> find next. GTK/Firefox/Chromium; some apps want F3.

    u = "C-z"; # undo (U -> redo, in [nav+shift])
    x = "delete"; # forward delete (X -> backspace, in [nav+shift])
    y = "C-c"; # yank -> copy
    p = "C-v"; # put -> paste
  };
in
{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];

      settings.main = {
        rightalt = "hangeul"; # keyd's name for KEY_HANGEUL (122)
        # Tap for a normal Caps Lock toggle, hold for the layer — the same
        # split Karabiner does with to_if_alone on macOS.
        capslock = "overload(nav, capslock)";
      };

      settings.nav = nav;

      # A composite layer fires only while *all* of its constituent layers are
      # held, and — unlike a passed-through modifier — it strips those layers'
      # modifiers from the output. That is exactly what the shifted commands
      # need: `$` must emit End, not Shift-End (which would select instead of
      # move). keyd requires composite layers to be declared after the layers
      # they are built from, which is what this option is for.
      #
      # `[` and `]` are spelled leftbrace/rightbrace: keyd treats any line
      # starting with `[` as a section header, so the literal key name cannot
      # appear on the left-hand side. Comments get their own lines for a
      # related reason — `#` is a key name to keyd (Shift-3), not a trailing
      # comment marker.
      extraConfig = ''
        [nav+shift]

        # $ -> line end
        4 = end
        # { -> paragraph up
        leftbrace = C-up
        # } -> paragraph down
        rightbrace = C-down
        # G -> document bottom
        g = C-end
        # N -> find previous
        n = C-S-g
        # X -> delete backwards
        x = backspace
        # U -> redo
        u = C-S-z
      '';
    };
  };
}
