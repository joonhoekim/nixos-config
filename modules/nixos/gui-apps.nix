{ config, lib, pkgs, user, ... }:

# NixOS 의 GUI 앱. macOS cask(../darwin/casks.nix)와 같은 구조 — core 는 늘, 나머지는 호스트의
# local.guiApps 로 고른다(목록이 통째로 바뀐다). 고르는 기준은 디스크다(docs/packages/footprint.md).
let
  core = with pkgs; {
    inherit vscode;
    # apps/rice/wall --yazi 가 직접 띄운다. 빼면 그 키바인드가 아무 창도 없이 끝난다.
    inherit ghostty;
  };

  optional = with pkgs; {
    # 브라우저
    inherit brave google-chrome firefox-devedition;

    # 보기
    inherit mpv;
    inherit zathura;

    # 프로세스는 btop 등 CLI 가 낫다. 이 둘은 GPU·디스크·네트워크를 시간축으로 보고 터미널 없이 닿는 자리다.
    inherit mission-center;           # 780M 사용률도 읽는다
    inherit resources;

    # 그림
    inherit krita gimp inkscape;

    # Linux 짝이 없는 cask(stats, iina)는 macOS 에만 있다.
    inherit zed-editor dbeaver-bin redisinsight bruno onlyoffice-desktopeditors;

    # Mac 에서 이 기계로 들어오는 원격 데스크톱(docs/tailscale.md). `rustdesk` 는 이름만 같은 예전 Sciter UI 빌드라 cache.nixos.org 에 없어 로컬에서 십 분 넘게 짓는다.
    # 이 이름이 목록에 있으면 rustdesk.nix 가 제어받는 쪽 서비스도 켠다.
    rustdesk = rustdesk-flutter;
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
