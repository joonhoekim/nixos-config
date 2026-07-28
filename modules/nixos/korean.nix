# Korean localization for NixOS, ported from the previous machine config:
# locale, input method (fcitx5 + Hangul), Right Alt -> Hangul remap (keyd),
# and CJK fonts + fallbacks. All of this is machine-independent.
#
# Imported by hosts/nixos/default.nix.
{ pkgs, ... }:

{
  # Locale: English UI, Korean regional formats.
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
    LC_TIME = "ko_KR.UTF-8";
  };

  # keyd — system-wide evdev key remapping. Works in X11, Wayland, and TTY
  # uniformly because it acts below xkb. Right Alt -> Hangul keysym;
  # fcitx5-hangul then sees Hangul_Mode and toggles keyboard-us <-> hangul.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.rightalt = "hangeul"; # keyd's name for KEY_HANGEUL (122)
    };
  };

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
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    nanum
    nanum-gothic-coding # Korean monospace (Nanum Gothic Coding)
    d2coding            # Korean monospace (Naver D2Coding)
    pretendard
  ];

  # Make sure apps fall back to Korean-capable fonts.
  fonts.fontconfig.defaultFonts = {
    monospace = [ "D2Coding" "Noto Sans Mono CJK KR" ];
    sansSerif = [ "Pretendard" "Noto Sans CJK KR" ];
    serif     = [ "Noto Serif CJK KR" ];
    emoji     = [ "Noto Color Emoji" ];
  };
}
