{ pkgs, user, ... }:

# Galaxy Chromebook 1 — Intel, fanless 2-in-1 with a Wacom stylus and a touchscreen.
# 전체 그림: docs/galaxy-chromebook-1.md

{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
    ./hardware.nix
    ./touch.nix
  ];

  # 개발 묶음과 무거운 GUI 를 뺀다. 무게는 docs/packages/footprint.md, 지금 고른 것은
  # `nix run .#inventory`. containers 를 빼면 docker 데몬도 꺼진다(../common.nix).
  local.packages.bundles = [ "media" "mobile" ];
  local.guiApps = [
    "brave"
    "google-chrome"
    "firefox-devedition"
    "onlyoffice-desktopeditors"
    "dbeaver-bin"
    "mpv"
    "zathura"
    "resources"
  ];

  # No nav layer: it hangs off held Caps Lock, and that key here is the Chromebook
  # launcher, a modifier that cannot carry a layer. Why not Space: docs/galaxy-chromebook-1.md

  # 펌웨어가 BootOrder 앞쪽의 죽은 "Linux Boot Manager" 부터 시도한다(`bootctl status` 엔
  # 안 보인다). `efibootmgr -v` 로 보고 `-b <ID> -B` 로 지운다. 부팅 문제용이라 설치해 둔다.
  environment.systemPackages = [ pkgs.efibootmgr ];

  # Stays at the installed release; it pins stateful data, not the channel.
  system.stateVersion = "25.11";

  # ./home.nix merges into modules/nixos/home-manager.nix.
  home-manager.users.${user} = {
    imports = [ ./home.nix ];
    home.stateVersion = "25.11";
  };
}
