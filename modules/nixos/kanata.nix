# Caps Lock layer and Right Alt -> Hangul via kanata — the replacement for
# ./keyboard.nix (keyd) plus ./pointer (pointerd).
#
# NOT IMPORTED YET. hosts/nixos/common.nix still imports keyd + pointerd; this
# file is staged until it has been built and tried on a NixOS machine. To
# switch, in common.nix replace the ./keyboard.nix and ./pointer imports with
# this file, then on the machine check what kanata grabbed (below).
#
# Why kanata over keyd: keyd cannot emit REL_X/REL_Y, so the mouse half of the
# layer had to leave keyd as spare F-key sentinels and be turned into motion
# by a second process (./pointer/pointerd.py) — with the F-key/xkb-symbol
# collisions and stuck-key timeouts that split brings (see ./keyboard.nix).
# kanata moves the pointer itself from its own uinput device, so the whole
# layer is one config, and the same one Windows and the Debian tablet run.
#
# The layer itself lives in ../shared/kanata/nav.kbd; this file adds only
# what is NixOS-specific: the base layer and Right Alt.
#
# Device selection is kanata's autodetect: anything with a key in 1-115
# (kanata src/oskbd/linux.rs has_keyboard_keys). That also catches volume-key
# and headphone-jack devices, and grabbing one swallows its non-key events
# (switches like SW_HEADPHONE_INSERT) silently. Check per machine with
#     journalctl -u kanata-default -b | grep -E 'registering|excluded'
# and add any such device to `linux-dev-names-exclude` in extraDefCfg, as
# ../debian/kanata/kanata.kbd does.
#
# The nixpkgs module runs `kanata --check` on the generated config at build
# time, so a syntax error fails the rebuild rather than the service.
{ ... }:

{
  services.kanata = {
    enable = true;

    keyboards.default = {
      # Without this, keys no layer maps (x, z, …) bypass kanata's state
      # machine, so tap-hold-press on Caps cannot see them as the other key
      # that commits the hold.
      extraDefCfg = ''
        process-unmapped-keys yes
      '';

      # The base layer must come before nav.kbd: the first layer defined is
      # the one kanata starts in.
      #
      # Right Alt goes out as KEY_HANGEUL (122) for fcitx5-hangul, which binds
      # the Hangul keysym (./korean.nix, Hotkey/TriggerKeys). kanata has no
      # Linux name for 122 — `kana` is KEY_KATAKANAHIRAGANA there (kanata
      # parser/src/keys/mod.rs) — so it is named here by code.
      config = ''
        (deflocalkeys-linux
          hngl 122
        )

        (deflayermap (base)
          caps @caps
          lsft @sl
          rsft @sr
          ralt hngl
        )

        ${builtins.readFile ../shared/kanata/nav.kbd}
      '';
    };
  };
}
