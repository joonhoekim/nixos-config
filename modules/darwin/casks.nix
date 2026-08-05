_:

[
  # Development Tools
  # NOTE: Docker Desktop removed — container runtime is now colima + lima
  # (declared in modules/shared/packages.nix); docker CLI comes from nixpkgs.
  "visual-studio-code"
  "zed"                # fast, collaborative code editor
  "iterm2"
  "postman"
  "bruno"              # git-friendly API client (collections as repo files)
  "dbeaver-community"  # universal database tool / SQL client
  "redis-insight"       # official Redis GUI

  # Productivity Tools
  "sol"                # launcher / command palette (replaces Raycast)

  # Terminals
  "ghostty"            # daily driver
  # Secondary terminal. `wezterm@nightly` rather than `wezterm`: upstream's
  # last tagged stable is the 2024-02 build, which predates several macOS
  # releases; the nightly cask is what the project actually keeps current.
  # Config (and the pywal palette wiring) is in modules/darwin/rice/wezterm.
  "wezterm@nightly"

  # Window manager / Keyboard / System utilities
  #
  # NOTE: the tiling WM is now rift, which is a brew *formula* and therefore
  # lives in ./brews.nix, not here. AeroSpace stays installed as the fallback —
  # it no longer starts at login (hosts/darwin/default.nix), so it costs
  # nothing until `open -a AeroSpace`. Drop this line once rift has proven out.
  "aerospace"          # tiling window manager (from nikitabobko/tap), stand-by
  "karabiner-elements"
  # eul(메뉴바 시스템 모니터)은 stats와 완전히 겹친다 — stats가 CPU/메모리/디스크/
  # 네트워크에 더해 센서·배터리·GPU까지 보여주고 설정 UI도 낫다. 아래 "Utility
  # Tools"의 stats 하나로 통일. 되살리려면 이 줄과 함께
  # modules/darwin/eul.nix import, hosts/darwin/default.nix의 eul LaunchAgent를
  # 같이 살려야 한다.
  # "eul"

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
  "stats"              # 메뉴바 시스템 모니터 (eul 대체). 로그인 실행은
                       # hosts/darwin/default.nix의 LaunchAgent가 담당한다.
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
