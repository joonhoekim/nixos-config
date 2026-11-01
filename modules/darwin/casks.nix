{ config, lib, ... }:

# macOS GUI 앱(Homebrew cask). 구조는 CLI 묶음(../shared/package-bundles.nix)과 같다 —
# `core` 는 모든 Mac 에 깔리고, 나머지는 호스트가 `local.casks` 로 고른다(기본값은 전부).
#
#   local.casks = [ "google-chrome" "onlyoffice" ];   # 목록이 통째로 바뀐다
#
# cask 에 매인 설정 — Dock(./home-manager.nix), 기본 앱 핸들러(./default-apps.nix),
# Stats·LinearMouse 의 LaunchAgent(hosts/darwin/common.nix) — 은 최종 homebrew.casks
# 를 보고 따라 빠진다. 그래서 그쪽은 이 파일의 목록이 아니라 homebrew.casks 를 읽는다.
let
  # 어느 Mac 이든, 가볍게 쓰는 기계여도 깐다.
  core = [
    "visual-studio-code"
  ];

  optional = [
    # Development Tools
    # 컨테이너 런타임은 cask 가 아니다 — colima + lima 와 docker CLI 를 nix 가 깐다
    # (modules/shared/packages.nix).
    "zed"                # fast, collaborative code editor
    "bruno"              # git-friendly API client (collections as repo files)
    "dbeaver-community"  # universal database tool / SQL client
    "redis-insight"       # official Redis GUI

    # Terminals. 주 터미널은 subline-terminal 이고 apps/subline-terminal 이 깐다.
    # 아래 둘은 참고용이다.
    "ghostty"
    # `wezterm@nightly`: 안정판은 2024-02 빌드에서 멈춰 있다. 설정은
    # modules/darwin/rice/wezterm, apps/demo 가 녹화에 쓴다.
    "wezterm@nightly"

    # Window manager / Keyboard / System utilities
    #
    # 타일링 WM 은 cask 가 아니다 — rift-grid 를 apps/rift-grid 가 빌드·서명해 깐다.
    # 키 리매핑은 cask 가 아니다 — kanata 와 그 드라이버를 nix 가 깐다
    # (modules/darwin/kanata.nix). Karabiner-Elements 는 같이 두면 안 된다: 드라이버
    # 데몬의 판이 kanata 와 안 맞고, 둘 다 키보드를 독점으로 잡으려 한다.
    #
    # 트랙패드는 자연스러운 스크롤 그대로 두고 마우스 휠만 뒤집는다. 설정과 근거는
    # modules/darwin/rice/linearmouse/.
    "linearmouse"

    # Browsers
    "google-chrome"
    "brave-browser"
    "firefox@developer-edition"
    "zen"                # Firefox-based, arc-like workspaces (cask token is
                         # "zen"; it was renamed from "zen-browser" upstream)

    # Communication Tools
    # "discord"
    # "notion"
    # "slack"
    # "telegram"
    # "zoom"

    # Utility Tools
    "stats"              # 메뉴바 시스템 모니터. 로그인 실행은
                         # hosts/darwin/common.nix의 LaunchAgent가 담당한다.
    # "syncthing"
    # "1password"
    # "rectangle"

    # Entertainment Tools
    # "spotify"
    # "vlc"
    "iina"

    # Office
    "onlyoffice"
  ];
in
{
  options.local.casks = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = optional;
    description = "core 외에 이 Mac 에 깔 cask.";
  };

  config.homebrew.casks = core ++ config.local.casks;
}
