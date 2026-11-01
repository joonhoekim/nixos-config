{ config, lib, pkgs, user, ... }:

# NixOS 의 GUI 앱. 구조는 macOS 의 cask(../darwin/casks.nix)와 같다 — `core` 는 모든
# NixOS 호스트에 깔리고, 나머지는 호스트가 `local.guiApps` 로 이름을 골라 더한다
# (기본값은 전부).
#
#   local.guiApps = [ "brave" "mpv" ];   # 목록이 통째로 바뀐다
#
# 고른 것은 다른 도구와 같은 home.packages 로 간다. 깔려 있기만 한 GUI 앱은 메모리를
# 쓰지 않으므로, 고르는 기준은 디스크다(docs/packages/footprint.md).
let
  # 어느 NixOS 기계든 깐다.
  core = with pkgs; {
    inherit vscode;
    # apps/rice/wall --yazi 가 미리보기 터미널로 ghostty 를 직접 띄운다. 빼면 그
    # 키바인드가 아무 창도 없이 끝난다.
    inherit ghostty;
  };

  optional = with pkgs; {
    # 브라우저
    inherit brave google-chrome firefox-devedition;

    # 보기
    inherit mpv;         # video player
    inherit zathura;     # PDF viewer

    # GUI 시스템 모니터. ../shared/packages.nix 의 btop / bottom / htop / procs 가
    # 프로세스를 보는 일은 더 잘한다. 이 둘은 GPU·디스크·네트워크를 한 화면에
    # 놓고 시간축으로 보는 일, 그리고 터미널이 없는 상태에서 손이 닿는 자리를 채운다.
    inherit mission-center;           # CPU/메모리/디스크/네트워크/GPU 탭. 780M 사용률도 읽는다
    inherit resources;                # GTK4/libadwaita. 가볍고 프로세스 kill 까지

    # 그림
    inherit krita gimp inkscape;

    # macOS cask 의 Linux 짝. Linux 짝이 없는 cask(stats, iina)는 macOS 에만 있다 —
    # btop/bottom 과 mpv 가 그 자리를 맡는다.
    inherit zed-editor dbeaver-bin redisinsight bruno onlyoffice-desktopeditors;
  };
in
{
  options.local.guiApps = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (builtins.attrNames optional));
    default = builtins.attrNames optional;
    description = "core 외에 이 NixOS 호스트에 깔 GUI 앱의 이름.";
  };

  config.home-manager.users.${user}.home.packages =
    builtins.attrValues core ++ map (n: optional.${n}) config.local.guiApps;
}
