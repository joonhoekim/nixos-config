# 한국어 로케일·입력기(fcitx5 + Hangul)·CJK 폰트. 한/영 리맵은 ./keyboard.nix.
# 전체 그림(한/영 키가 거치는 세 키코드 이름공간, 확인 명령): docs/korean-input.md
{ pkgs, ... }:

{
  # LC_TIME 만 en_DK: 영어 이름에 ISO 8601(%Y-%m-%d, %T, am_pm 없음). ko_KR 이면 Qt 가 요일·12시간제를
  # 여기서 가져가 DMS 바 시계에 토 / 오후 가 섞인다.
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

  # nixpkgs 의 Electron/Chromium 래퍼는 Wayland IME 플래그(--enable-wayland-ime 등)를 전부 이 변수 뒤에 둔다.
  # 한글 누락을 고친 것은 아니다(그건 overlays/vscode-xterm-hangul.nix) — 경위: docs/postmortems/2026-08-05-vscode-terminal-hangul.md
  # 세션 변수라 rebuild 가 아니라 로그아웃해야 먹는다.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true; # Wayland text-input-v3 (GNOME/Mutter, GTK apps)
      addons = with pkgs; [
        fcitx5-hangul
        fcitx5-gtk
        qt6Packages.fcitx5-qt
        qt6Packages.fcitx5-configtool
      ];
      # fcitx5 는 ~/.config/fcitx5/* 를 먼저 읽고 시작할 때 profile 을 직접 쓴다. 그래서 이건 시드다 —
      # 사용자 사본이 있는 머신은 rebuild 뒤 ~/.config/fcitx5/{profile,config} 를 한 번 지워야 먹는다.
      settings = {
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            # 토글이 켜는 IM. 시작 상태가 아니다(ActiveByDefault 가 false 라 입력란은 영어로 열린다).
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
          # 정확히 둘이어야 한다 — 셋째가 있으면 아래 EnumerateWithTriggerKeys 의 enumerate 로 빠진다.
          GroupOrder."0" = "Default";
        };

        # /etc/xdg/fcitx5/config. EnumerateWithTriggerKeys 를 끄면 trigger() 가 무조건 toggle() 한다
        # (src/lib/fcitx/instance.cpp 의 Instance::trigger). 켜 두면 그룹을 순환한다.
        globalOptions = {
          # 문자열 "False" 여야 한다. toINI 는 bool 을 `false` 로 쓰는데 fcitx5 는 "True"/"False" 만 받고
          # 그 밖은 조용히 기본값으로 돌린다(marshallfunction.cpp 의 unmarshallOption(bool)). 아래 hangul 도 같다.
          Hotkey.EnumerateWithTriggerKeys = "False";

          # 상류 기본값이 바뀌어도 한/영이 안 사라지게 고정한다. Hangul 은 keyd 가 Right Alt 로 내는 keysym,
          # Control+space 는 Hangul 경로를 디버깅할 때의 탈출구다.
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

  # 공통 한글 폰트는 modules/shared/fonts.nix. OnlyOffice 는 fontconfig 를 안 써서
  # 오피스에서도 쓸 폰트면 overlays/onlyoffice-fonts.nix 도 같이 고친다.
  fonts.packages = with pkgs; [
    noto-fonts-cjk-serif-static # VF 판은 OnlyOffice 에서 Thin 으로 그려진다 (아래 sans 와 같은 이유)
    nanum
    nanum-gothic-coding
    d2coding            # 폴백이 찾는 "D2Coding" 패밀리. Nerd 패치판은 패밀리 이름이 달라 대신 못 한다.
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "D2Coding" "Noto Sans Mono CJK KR" ];
    sansSerif = [ "Pretendard" "Noto Sans CJK KR" ];
    serif     = [ "Noto Serif CJK KR" ];
    emoji     = [ "Noto Color Emoji" ];
  };
}
