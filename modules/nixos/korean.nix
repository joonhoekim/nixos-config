# 한국어 로케일·CJK 폰트. 입력기는 여기 없다: 한글은 subline 내장 입력기가 조합하고(keyboard.input_method,
# 외부 입력기가 없으면 auto 가 builtin 을 고른다), 한/영 키는 ./kanata.nix 가 낸다. 전체 그림: docs/korean-input.md
{ pkgs, ... }:

{
  # LC_TIME 만 en_DK: 영어 이름에 ISO 8601(%Y-%m-%d, %T, am_pm 없음). ko_KR 이면 요일·12시간제가
  # 한국어로 나와 영어 UI 의 시계에 토 / 오후 가 섞인다.
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
