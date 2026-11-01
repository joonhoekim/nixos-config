{ pkgs, user, ... }:

# Galaxy Chromebook 1 — Intel, fanless 2-in-1 with a Wacom stylus and a
# touchscreen.
#
# Its stateVersions are pinned to the release it was actually installed at
# (25.11), which is older than the repo default — see below.

{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
    ./hardware.nix
    ./touch.nix
  ];

  # 전체 개발을 돌릴 성능이 아니라서, 디스크를 많이 쓰는 개발 묶음과 그림·개발용
  # GUI 를 뺀다. core 의 CLI 와 GUI(VS Code, ghostty)는 항상 깔린다. 무엇이 얼마나
  # 무거운지는 docs/packages/footprint.md, 지금 고른 것은 `nix run .#inventory`.
  #
  # containers 를 빼면 docker 데몬도 꺼진다(../common.nix).
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

  # No navigation layer on this host, and nothing to configure for it. The
  # layer in modules/nixos/keyboard.nix hangs off held Caps Lock, and this
  # chassis has no Caps Lock key — that position is the Chromebook
  # launcher/search key, which is a modifier and cannot carry a layer. Space
  # could, but only with the timing guards a space trigger needs to stay out of
  # the way of typing, and this machine browses far more than it types.

  # 이 기계의 EFI NVRAM 에는 죽은 "Linux Boot Manager" 항목이 BootOrder 에서 살아
  # 있는 항목보다 앞에 쌓일 수 있다. 그러면 펌웨어가 그것부터 시도해
  #
  #   Booting from 'Linux Boot Manager' failed: Not Found
  #
  # 를 찍고 나서야 살아 있는 항목으로 넘어간다. `bootctl status` 는 장치 경로를
  # 해석할 수 있는 항목만 보이므로 바로 그 깨진 항목을 숨긴다. `efibootmgr -v` 로
  # 보고 `efibootmgr -b <ID> -B` 로 지운다.
  # 경위는 docs/postmortems/2026-08-14-galaxy-chromebook-1-efi-boot-entries.md.
  #
  # Kept installed rather than reached for with `nix run`: the situation it
  # diagnoses is a boot problem, and a machine that will not boot is a poor
  # place to be downloading packages.
  environment.systemPackages = [ pkgs.efibootmgr ];

  # Installed at 25.11 and stays there. stateVersion pins stateful-data
  # layouts, not the nixpkgs channel — the flake still tracks nixos-unstable,
  # so packages keep moving. common.nix sets 26.11 with mkDefault for hosts
  # that get installed fresh.
  system.stateVersion = "25.11";

  # Merges with the base home-manager config the flake wires up
  # (modules/nixos/home-manager.nix); ./home.nix adds this machine's bits.
  home-manager.users.${user} = {
    imports = [ ./home.nix ];
    home.stateVersion = "25.11";
  };
}
