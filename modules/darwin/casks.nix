_:

[
  # Development Tools
  # 컨테이너 런타임은 cask 가 아니다 — colima + lima 와 docker CLI 를 nix 가 깐다
  # (modules/shared/packages.nix).
  "visual-studio-code"
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
]
