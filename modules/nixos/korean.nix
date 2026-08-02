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
  # navigation layer on held Caps Lock. fcitx5-hangul sees the resulting
  # Hangul_Mode and toggles keyboard-us <-> hangul.

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
      # NOTE: fcitx5 reads ~/.config/fcitx5/* before /etc/xdg/fcitx5/*. After
      # rebuilding, remove user-local overrides for these to take effect.
      settings = {
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "hangul"; # start in Hangul; Right Alt toggles to EN
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "hangul";
            Layout = "us"; # use US physical layout while in Hangul IM
          };
          "Groups/0/Items/2" = {
            Name = "keyboard-kr";
            Layout = "";
          };
          GroupOrder."0" = "Default";
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
