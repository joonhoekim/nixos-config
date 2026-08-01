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
#   - Caps Lock held -> a TouchCursor navigation layer.
#
# TouchCursor (https://github.com/martin-stone/touchcursor) solves exactly one
# problem — moving the cursor without leaving the home row — and solves it
# spatially: hold the trigger, and `ijkl` is an inverted-T arrow cluster under
# the right hand. Nothing about it has to be memorised.
#
# It is here rather than a vim layer (which this file used to hold; the parked
# version is ./keyboard.nix.vim) because it is what the Windows machines run,
# and TouchCursor cannot import a config — every box is set up by hand, so one
# vocabulary across all of them is worth more than notational purity.
#
# The trigger is Caps Lock on every machine, which is the single setting
# changed from stock TouchCursor there and the one thing this file has to
# match. It also happens to be the trigger the mapping wants: TouchCursor's
# default is space, and a space trigger has to be defended against the typing
# it sits in the middle of (an idle timeout so fast rolls don't open the layer,
# plus emitting the swallowed space ahead of any key the layer doesn't map).
# Caps Lock is dead weight otherwise, so it needs none of that.
#
# Two consequences of the mapping worth knowing:
#
#   - Every binding is unshifted, so Shift is never part of a command and stays
#     free to extend a selection: Caps+Shift+j selects left, Caps+Shift+o
#     selects to end of line. The vim layer could not do this for `$ { } G N`,
#     because there Shift *was* the command.
#   - Nothing in the layer composes. That is not a limitation to work around;
#     it is the whole design. Composition (`d2w`, `ci"`) needs an application
#     that parses a grammar, which is what an editor is for — see
#     ./keyboard.nix.vim for the long version of that argument.
#
# The vim motions TouchCursor has no answer for are kept on the keys it leaves
# free: w/e/b word motions, g/G document ends, / for find.
#
# Imported by hosts/nixos/common.nix.
{ ... }:

let
  # [nav] — a plain layer, not a modifier layer: keys with no binding here type
  # their own letter while Caps Lock is held.
  nav = {
    # TouchCursor proper — the mapping muscle memory is already trained on.
    # Inverted T under the right hand, one row up from the home row.
    i = "up";
    j = "left";
    k = "down";
    l = "right";

    u = "home"; # line start (⌘← in the macOS original)
    o = "end"; # line end   (⌘→)

    h = "pageup";
    n = "pagedown";

    p = "backspace";
    m = "delete"; # forward delete
    y = "insert";

    # Borrowed from vim, on keys TouchCursor leaves unmapped. These are the
    # motions it has no equivalent for at all, not stylistic replacements.
    w = "C-right"; # word forward
    e = "C-right";
    b = "C-left"; # word back
    g = "C-home"; # gg -> document top (G -> bottom, in [nav+shift])
    slash = "C-f"; # find
  };
in
{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];

      settings.main = {
        rightalt = "hangeul"; # keyd's name for KEY_HANGEUL (122)
        # Tap for a normal Caps Lock toggle, hold for the layer — same as
        # tapping the trigger key in TouchCursor itself.
        capslock = "overload(nav, capslock)";
      };

      settings.nav = nav;

      # A composite layer fires only while all of its constituent layers are
      # held, and strips their modifiers from the output — Shift here is part of
      # the command (`G`), not a selection. keyd requires composite layers to be
      # declared after the layers they are built from, which is what this option
      # is for.
      extraConfig = ''
        [nav+shift]

        # G -> document bottom
        g = C-end
      '';
    };
  };
}
