{ lib, pkgs, user, ... }:

# Galaxy Chromebook 1 — Intel, fanless 2-in-1 with a Wacom stylus and a touchscreen.
# 전체 그림: docs/galaxy-chromebook-1.md

{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
    ./hardware.nix
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
    "snapshot"
  ];

  # kanata 를 끈다. 접으면(SW_TABLET_MODE) libinput 이 내장 키보드를 끄는데, kanata 가 그 키보드를 grab 해
  # 가상 키보드로 다시 내면 억제 대상이 아니게 되어 등 뒤로 간 자판이 눌린다. 잃는 것은 없다: Caps 레이어는
  # 이 기계에 걸 키가 없고(그 자리는 Chromebook 런처, docs/galaxy-chromebook-1.md), Right Alt 한/영은 subline 의
  # xkb 옵션 기본값 korean:ralt_hangul 이 낸다. 회전·화면 키보드·태블릿 모드는 subline 이 한다.
  services.kanata.enable = lib.mkForce false;

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
