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
#   - Caps Lock held -> a layer with a hand each: navigation on the right,
#     the mouse on the left.
#
# The right hand is TouchCursor (https://github.com/martin-stone/touchcursor),
# which solves exactly one problem — moving the cursor without leaving the home
# row — and solves it spatially: hold the trigger, and `ijkl` is an inverted-T
# arrow cluster. Nothing about it has to be memorised.
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
# The left hand is a mouse: wasd steers, q/e scroll, f/r click, and Shift is
# fine aim. It cost this file the vim motions that used to sit there —
# `w`/`e`/`b` for words, `g`/`G` for the document ends — which is a real loss,
# and the trade the layer is making: those four keys duplicated what an editor
# already does better, while nothing else on the machine was going to replace a
# physical mouse. The buttons are also on 8/9/0 for the other hand, which is
# where they started; f/r arrived later, once it was obvious that reaching the
# number row broke the one-handed grip the rest of it was built for.
#
# keyd cannot do the mouse half. Of the 319 key names it knows, `leftmouse`,
# `middlemouse`, `rightmouse` and `scroll{up,down,left,right}` are the entire
# mouse vocabulary — there is no action anywhere in it that emits REL_X/REL_Y,
# so a pointer cannot be moved from this file at any speed. So the mouse keys
# emit spare F-keys instead, and ./pointer reads those and drives a uinput
# pointer. Buttons and scrolling could have stayed here, but they leave through
# the same device as the motion instead, so that holding f and steering with
# wasd is one coherent drag.
#
# Which F-keys is not a free choice, and the first draft got it wrong. They are
# not spare in the way they look: the stock `us` keymap gives F13-F18 the
# XF86Tools and XF86Launch5-9 symbols, F20 XF86AudioMicMute, F21-F23 the
# touchpad toggles, and leaves only F19 and F24 plain. The middle button sat on
# F20 for a day and muted the microphone every time it was pressed, because
# niri binds XF86AudioMicMute (./niri/rice/config.kdl). So the two plain keys
# went to the two buttons that get used, F20/F21/F23 are avoided outright, and
# the rest sit on symbols nothing here binds. To check before moving one:
#
#     xkbcli compile-keymap --layout us | grep FK
#
# Two consequences of the mapping worth knowing:
#
#   - Every navigation binding is unshifted, so Shift is never part of a
#     command on the right hand and stays free to extend a selection:
#     Caps+Shift+j selects left, Caps+Shift+o selects to end of line. The vim
#     layer could not do this for `$ { } G N`, because there Shift *was* the
#     command. On the left hand Shift does mean something — slow motion, and
#     the horizontal scroll axis — but that is read by ./pointer from the
#     shift key itself, not expressed here as a `[nav+shift]` composite layer.
#     It has to be, because keyd resolves a binding when the key goes down: a
#     composite layer could not slow a `w` that was already held, and pressing
#     Shift to steady an overshoot in progress is the whole point of having it.
#   - Nothing in the layer composes. That is not a limitation to work around;
#     it is the whole design. Composition (`d2w`, `ci"`) needs an application
#     that parses a grammar, which is what an editor is for — see
#     ./keyboard.nix.vim for the long version of that argument.
#
# Imported by hosts/nixos/common.nix.
{ ... }:

let
  # [nav] — a plain layer, not a modifier layer: keys with no binding here type
  # their own letter while Caps Lock is held.
  nav = {
    # Right hand: TouchCursor proper — the mapping muscle memory is already
    # trained on. Inverted T one row up from the home row.
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

    slash = "C-f"; # find — borrowed from vim, on a key TouchCursor leaves free

    # Mouse: sentinels for ./pointer, which owns everything below. Which
    # F-keys these are is not arbitrary — see the header above.
    w = "f13"; # up
    a = "f14"; # left
    s = "f15"; # down
    d = "f16"; # right

    q = "f17"; # wheel up   / Shift: scroll left
    e = "f18"; # wheel down / Shift: scroll right

    # Two keys per button: `f`/`r` under the steering hand so the whole mouse
    # is one-handed, and `8`/`0` for the other hand when it is free anyway.
    # Both spellings emit the same sentinel, so ./pointer never learns there
    # are two of them.
    f = "f19"; # left button
    "8" = "f19";
    r = "f24"; # right button
    "0" = "f24";
    "9" = "f22"; # middle button
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
    };
  };
}
