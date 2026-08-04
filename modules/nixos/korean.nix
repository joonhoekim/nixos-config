# Korean localization for NixOS, ported from the previous machine config:
# locale, input method (fcitx5 + Hangul), and CJK fonts + fallbacks. All of
# this is machine-independent. The 한/영 key remap itself lives in
# ./keyboard.nix with the rest of the keyd config.
#
# Imported by hosts/nixos/default.nix.
{ pkgs, ... }:

{
  # Locale: English UI, Korean regional formats.
  #
  # LC_TIME is the exception: it used to be ko_KR, which made anything that
  # renders a date do it in Korean — `date` printing "2026. 08. 01. (토)", and
  # DankMaterialShell's bar clock showing 토 / 오후 next to its English labels,
  # since Qt takes day names and the 12h-vs-24h choice from this category.
  #
  # en_DK is the standard way out: an English locale (Sat, August) whose LC_TIME
  # is ISO 8601 — d_fmt "%Y-%m-%d", t_fmt "%T", empty am_pm. So messages and
  # names stay English and searchable, and dates stop being US-ordered.
  #
  # Everything listed here is generated automatically: i18n.supportedLocales
  # defaults to the union of defaultLocale and these values.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ko_KR.UTF-8";
    LC_IDENTIFICATION = "ko_KR.UTF-8";
    LC_MEASUREMENT = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
    LC_NAME = "ko_KR.UTF-8";
    LC_NUMERIC = "ko_KR.UTF-8";
    LC_PAPER = "ko_KR.UTF-8";
    LC_TELEPHONE = "ko_KR.UTF-8";
    LC_TIME = "en_DK.UTF-8"; # English names, ISO YYYY-MM-DD, 24-hour
  };

  # 한/영 is Right Alt -> Hangul, remapped by keyd in ./keyboard.nix rather
  # than here: keyd takes one config per machine, and this box also puts a
  # navigation layer on held Caps Lock.
  #
  # The full chain, since it crosses three keycode namespaces and every one of
  # them names the key differently:
  #
  #   keyd `rightalt = hangeul`  ->  evdev KEY_HANGEUL (122)
  #     -> xkb <HNGL>, which is keycode 130 (evdev + 8)
  #     -> keysym `Hangul`, from symbols/pc — its only section, pc105, so every
  #        layout including a bare `us` carries it
  #     -> fcitx5 Hotkey/TriggerKeys -> toggle keyboard-us <-> hangul
  #
  # To check a hop rather than guess at it: `sudo evtest` on the *keyd virtual
  # keyboard* device for the first, and fcitx5's own key log for the last —
  #
  #   gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  #     --method org.fcitx.Fcitx.Controller1.SetLogRule "keytrace=5"
  #   journalctl --user -fu 'app-org.fcitx.Fcitx5@autostart.service'
  #
  # which prints `KeyEvent: Key(Hangul ...) keycode: 130` when the key lands.
  # Pass "" to SetLogRule to turn it back off; it is very noisy.

  # Korean input via fcitx5 + Hangul engine, tuned for GNOME / Wayland.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true; # Wayland text-input-v3 (GNOME/Mutter, GTK apps)
      addons = with pkgs; [
        fcitx5-hangul
        fcitx5-gtk                      # GTK3/GTK4 IM module (GNOME apps)
        qt6Packages.fcitx5-qt           # Qt6 IM module (Qt apps under GNOME)
        qt6Packages.fcitx5-configtool   # GUI configurator
      ];
      # Declarative profile — adds Hangul to the active input-method group.
      # NOTE: fcitx5 reads ~/.config/fcitx5/* before /etc/xdg/fcitx5/*, and it
      # *writes* ~/.config/fcitx5/profile itself on startup. So everything below
      # is a seed for a machine that has no user-local copy yet; on one that
      # does, delete ~/.config/fcitx5/{profile,config} once after rebuilding or
      # none of it takes effect. (i18n.inputMethod.fcitx5.ignoreUserConfig would
      # make this unconditional, at the cost of fcitx5 never persisting anything
      # — including whatever the config GUI writes. Not worth it here.)
      settings = {
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            # Which IM the toggle turns *on*. Not the startup state: fcitx5's
            # Behavior/ActiveByDefault is false, so a text field opens inactive
            # — that is, on Items/0, English — and 한/영 activates this one.
            DefaultIM = "hangul";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "hangul";
            Layout = "us"; # use US physical layout while in Hangul IM
          };
          # Exactly two entries, and that is load-bearing — see the
          # EnumerateWithTriggerKeys note below. A third one used to sit here:
          #
          #   "Groups/0/Items/2" = { Name = "keyboard-kr"; Layout = ""; };
          #
          # It bought nothing. keyboard-kr is an xkb layout, not an engine; the
          # `kr` layout is US QWERTY with a couple of extra keys, so selecting
          # it types Latin exactly like keyboard-us does. Hangul comes from the
          # hangul *engine* above, never from the layout. All it did was give
          # the trigger key a third state that looks identical to the first.
          GroupOrder."0" = "Default";
        };

        # Written to /etc/xdg/fcitx5/config. There was no such file at all
        # before — every hotkey came from fcitx5's compiled-in defaults.
        #
        # EnumerateWithTriggerKeys is the one that matters. fcitx5's
        # Instance::trigger() branches like this (src/lib/fcitx/instance.cpp):
        #
        #   if (!enumerateWithTriggerKeys() || (firstTrigger_ && isActive()) ||
        #       (enumerateSkipFirst() && inputMethodList().size() <= 2))
        #     toggle(ic);
        #   else
        #     enumerate(ic, true);
        #
        # Left at its default (true), the trigger key can fall through to
        # enumerate() — cycling forward through the group rather than flipping
        # between two states. With the old three-entry group that meant
        # keyboard-us → hangul → keyboard-kr, and since two of those three type
        # Latin, 한/영 behaved as if it were half broken. Setting this false
        # makes trigger() unconditionally toggle(), which is what a 한/영 key
        # is supposed to do.
        globalOptions = {
          # "False", not false. The nixpkgs module renders this file with a
          # bare `lib.generators.toINI {}`, which spells a Nix bool `false`,
          # and fcitx5 only ever accepts "True"/"False" — case-sensitively,
          # falling back to the compiled-in default on anything else
          # (unmarshallOption(bool), src/lib/fcitx-config/marshallfunction.cpp).
          # A bool here therefore reads as "correct config that does nothing".
          # Same reason the hangul addon block below is quoted.
          Hotkey.EnumerateWithTriggerKeys = "False";

          # Pinned rather than inherited, so an upstream change to the defaults
          # cannot quietly take the 한/영 key away. Hangul is the keysym keyd
          # produces from Right Alt (see ./keyboard.nix); Control+space is kept
          # deliberately as an escape hatch for when the Hangul path itself is
          # what is being debugged. Zenkaku_Hankaku is in the stock list too and
          # is dropped here — nothing on this machine emits it.
          "Hotkey/TriggerKeys" = {
            "0" = "Hangul";
            "1" = "Control+space";
          };
        };
        addons = {
          hangul = {
            globalSection = {
              Keyboard = "Dubeolsik"; # 두벌식
              AutoReorder = "True";
              WordCommit = "False";
              HanjaMode = "False";
            };
            sections = {
              HanjaModeToggleKey = {
                "0" = "Hangul_Hanja";
                "1" = "F9";
              };
              PrevPage."0" = "Up";
              NextPage."0" = "Down";
              PrevCandidate."0" = "Shift+Tab";
              NextCandidate."0" = "Tab";
            };
          };
        };
      };
    };
  };

  # Korean / CJK fonts (merged with the general fonts in hosts/nixos).
  #
  # The shared set — D2Coding Nerd Font, Sarasa Gothic, Noto Sans CJK,
  # Pretendard, and the plain Noto/emoji faces — moved to
  # modules/shared/fonts.nix, because macOS turned out to need it too: it had
  # no Hangul face of its own to lend a terminal. What is left here is what
  # only this side wants.
  fonts.packages = with pkgs; [
    noto-fonts-cjk-serif
    nanum
    nanum-gothic-coding # Korean monospace (Nanum Gothic Coding)
    d2coding            # unpatched "D2Coding" — the family name the fallbacks
                        # below ask for. The Nerd patch is a different family
                        # ("D2CodingLigature Nerd Font"), so it can't stand in.
  ];

  # Make sure apps fall back to Korean-capable fonts.
  fonts.fontconfig.defaultFonts = {
    monospace = [ "D2Coding" "Noto Sans Mono CJK KR" ];
    sansSerif = [ "Pretendard" "Noto Sans CJK KR" ];
    serif     = [ "Noto Serif CJK KR" ];
    emoji     = [ "Noto Color Emoji" ];
  };
}
