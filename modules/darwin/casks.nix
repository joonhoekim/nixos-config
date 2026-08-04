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
  "eul"

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
  "stats"
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
