{ config, lib, ... }:

# core 는 모든 Mac, 나머지는 호스트가 `local.casks` 로 고른다(목록이 통째로 바뀐다).
# cask 에 매인 Dock·핸들러·LaunchAgent 는 이 목록이 아니라 최종 homebrew.casks 를 보고 따라 빠진다.
let
  core = [
    "visual-studio-code"
  ];

  optional = [
    # Development Tools
    # 컨테이너 런타임은 cask 가 아니라 nix 의 colima + lima + docker CLI 다(modules/shared/packages.nix).
    "zed"
    "bruno"
    "dbeaver-community"
    "redis-insight"

    # Terminals. 주 터미널은 apps/subline-terminal 이 까는 subline-terminal 이고 아래 둘은 참고용이다.
    "ghostty"
    # `wezterm@nightly`: 안정판은 2024-02 빌드에서 멈춰 있다. apps/demo 가 녹화에 쓴다.
    "wezterm@nightly"

    # Window manager / Keyboard / System utilities — rift-grid 와 kanata 는 cask 가 아니다.
    # Karabiner-Elements 를 같이 두면 안 된다: 드라이버 데몬 판이 kanata 와 안 맞고 둘 다 키보드를 독점하려 한다.
    "linearmouse"

    # Browsers
    "google-chrome"
    "brave-browser"
    "firefox@developer-edition"
    "zen"

    # Communication Tools
    # "discord"
    # "notion"
    # "slack"
    # "telegram"
    # "zoom"

    # Utility Tools
    "stats"              # 로그인 실행은 hosts/darwin/common.nix 의 LaunchAgent
    # NixOS 기계에 원격으로 들어가는 쪽. 받는 쪽은 modules/nixos/rustdesk.nix, 쓰는 법은 docs/tailscale.md
    "rustdesk"
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
