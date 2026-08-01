# PARKED — not imported by anything. Swap it in for ./keyboard.nix to use it.
#
# A vim/neovim navigation layer on held Caps Lock, ported from the
# Karabiner-Elements config this repo used to ship for macOS. It was the active
# NixOS layer for a while, on the theory that a vocabulary shared with neovim,
# yazi, lazygit, tmux copy-mode, less and vimium compounds, while a private
# mapping table does not. That argument still holds — it is just not the
# argument that decides this machine, which spends its editing hours in VS Code
# and its cursor-moving hours in a browser. ./keyboard.nix (TouchCursor) is
# what those hours are actually shaped like, and it is also what the Windows
# boxes run, which cannot import a config file at all.
#
# Two things were learned building this, and they are the reason it reads as a
# smaller idea than "vim on the OS":
#
#   1. The OS has no modes, and therefore no grammar. Vim's power is not `hjkl`
#      — it is composition: operator × count × motion/text-object (`d2w`,
#      `ci"`, `>ip`). Every one of those needs an application parsing a
#      keystroke *language*. keyd can only emit single key events, so a layer
#      like this borrows vim's vocabulary and none of its ceiling. Its actual
#      ceiling is a flat table of ~30 keys — the same ceiling TouchCursor has,
#      reached by a longer road. Raising it means adding vim support to the
#      applications (vimium, zsh `bindkey -v`, yazi), never to this file.
#
#   2. Shift is the OS's selection modifier, and vim spends Shift on commands.
#      Every binding below that lives in [nav+shift] — `$ { } G N X` — can only
#      ever move the cursor; it can never extend a selection, because the
#      composite layer has to strip Shift to keep `$` from emitting Shift-End.
#      The unshifted half (`hjkl`, `w e b`, `0`) selects fine. That split is
#      structural, not a tuning problem, and TouchCursor does not have it: every
#      TouchCursor binding is unshifted, so Shift stays free throughout.
#
# What is *not* here any more: the keys this layer had to invent because vim
# has no counterpart for them at the OS level — PageUp/PageDown had been put on
# `i` and `m` (insert and mark in real vim), and redo on `U` (undo-line in real
# vim, `C-r` being unreachable here). Inventing those quietly polluted the one
# thing the layer was for, so they are gone rather than parked. The remainder
# is only what vim actually defines.
{ ... }:

let
  # [nav] — a plain layer, not a modifier layer: keys with no binding here type
  # their own letter while Caps Lock is held. Shift is unbound and passes
  # through, so Caps+Shift+j extends a selection.
  nav = {
    # hjkl -> arrows
    h = "left";
    j = "down";
    k = "up";
    l = "right";

    # w/e -> word forward, b -> word back (Ctrl-arrow is the Linux equivalent
    # of the macOS Alt-arrow this was ported from)
    w = "C-right";
    e = "C-right";
    b = "C-left";

    "0" = "home"; # line start ($ = Shift-4 -> end, in [nav+shift])
    g = "C-home"; # gg -> document top (G -> bottom, in [nav+shift])

    slash = "C-f"; # / -> find
    n = "C-g"; # n -> find next. GTK/Firefox/Chromium; some apps want F3.

    u = "C-z"; # undo
    x = "delete"; # x -> delete under cursor (X -> backspace, in [nav+shift])
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
        rightalt = "hangeul";
        # Tap for a normal Caps Lock toggle, hold for the layer — the same
        # trigger, on the same key, that ./keyboard.nix uses. Only the
        # vocabulary differs between the two files.
        capslock = "overload(nav, capslock)";
      };

      settings.nav = nav;

      # Composite layer: fires only while both [nav] and Shift are held, and
      # strips their modifiers from the output, so `$` emits End rather than
      # Shift-End. keyd requires composites to be declared after the layers they
      # are built from, which is what this option is for. `[` and `]` are
      # spelled leftbrace/rightbrace because keyd reads any line starting with
      # `[` as a section header.
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
      '';
    };
  };
}
