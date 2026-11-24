{ config, lib, pkgs, user, ... }:

# NixOS 의 GUI 앱. macOS cask(../darwin/casks.nix)와 같은 구조 — core 는 늘, 나머지는 호스트의
# local.guiApps 로 고른다(목록이 통째로 바뀐다). 고르는 기준은 디스크다(docs/packages/footprint.md).
let
  core = with pkgs; {
    inherit vscode;
    # apps/rice/wall --yazi 가 직접 띄운다. 빼면 그 키바인드가 아무 창도 없이 끝난다.
    inherit ghostty;
    # 그림 파일의 기본 앱(아래 xdg.mime). 빼면 그 키가 다음 후보(브라우저)로 넘어간다.
    inherit loupe;
    inherit gnome-calculator;
  };

  optional = with pkgs; {
    # 브라우저
    inherit brave google-chrome firefox-devedition;

    # 보기
    inherit mpv;
    inherit zathura;

    # 카메라. PipeWire 카메라 노드를 직접 연다 — surface-pro-9 의 IPU6 센서는 libcamera→PipeWire 로만
    # 나와서 v4l2 장치를 여는 앱(cheese, guvcview)에는 카메라가 안 보인다.
    inherit snapshot;
    # 위치는 geoclue 에서 받는다. 이 이름이 목록에 있으면 아래에서 그 데몬도 켠다.
    inherit gnome-maps;
    inherit simple-scan;

    # 디스크 포맷·이미지 굽기, 키링에 든 암호 보기·지우기.
    inherit gnome-disk-utility seahorse;

    # 프로세스는 btop 등 CLI 가 낫다. 이 둘은 GPU·디스크·네트워크를 시간축으로 보고 터미널 없이 닿는 자리다.
    inherit mission-center;           # 780M 사용률도 읽는다
    inherit resources;

    # 그림
    inherit krita gimp inkscape;

    # 펜 필기·화이트보드. openboard 는 nixpkgs efe6f07 에서 빌드가 깨져 뺐다:
    # UBFFmpegVideoEncoder.cpp 가 AVCodec::sample_fmts 를 읽는데, ffmpeg_7·8·9 어느 것으로 override 해도 같은 오류다.
    inherit rnote xournalpp saber styluslabs-write lorien;

    # Linux 짝이 없는 cask(stats, iina)는 macOS 에만 있다.
    inherit zed-editor dbeaver-bin redisinsight bruno onlyoffice-desktopeditors;

    # Mac 에서 이 기계로 들어오는 원격 데스크톱(docs/tailscale.md). `rustdesk` 는 이름만 같은 예전 Sciter UI 빌드라 cache.nixos.org 에 없어 로컬에서 십 분 넘게 짓는다.
    # 이 이름이 목록에 있으면 rustdesk.nix 가 제어받는 쪽 서비스도 켠다.
    rustdesk = rustdesk-flutter;
    # RDP·VNC 클라이언트. Windows 로 나가는 원격 접속은 RustDesk 가 아니라 이것과 Windows 의 원격 데스크톱으로 한다.
    inherit remmina;
  };
in
{
  options.local.guiApps = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (builtins.attrNames optional));
    default = builtins.attrNames optional;
    description = "core 외에 이 NixOS 호스트에 깔 GUI 앱의 이름.";
  };

  config = {
    home-manager.users.${user}.home.packages =
      builtins.attrValues core ++ map (n: optional.${n}) config.local.guiApps;

    # 기기 사이 파일 주고받기. home.packages 가 아니라 nixpkgs 모듈로 켜는 것은 방화벽 때문이다:
    # nixos/modules/programs/localsend.nix 의 openFirewall(기본 켜짐)이 53317 을 TCP(파일 받는 HTTP)와
    # UDP(멀티캐스트 발견)로 연다. 닫혀 있으면 이 기계가 상대 목록에 안 뜨고 보내기도 조용히 실패한다.
    # Mac 짝은 ../darwin/casks.nix 의 core 에 있는 localsend cask.
    programs.localsend.enable = true;

    services.geoclue2.enable = builtins.elem "gnome-maps" config.local.guiApps;

    # 파일·링크를 여는 기본 앱. /etc/xdg/mimeapps.list 의 시스템 기본값이라 ~/.config/mimeapps.list
    # (subline 설정 → 앱, `gio mime`, 각 앱의 "기본으로" 버튼이 쓰는 곳)가 키마다 이긴다. 그래서 거기서 바꾼
    # 값은 리빌드에도 남고, 여기를 바꿔도 사용자가 이미 고른 키에는 안 보인다. 앱이 없는 호스트에서는 GIO 가
    # 이 줄을 건너뛰고 다음 후보로 간다. 폴더(inode/directory)는 ./thunar.nix.
    xdg.mime.defaultApplications =
      let
        browser = "google-chrome.desktop";
        image = "org.gnome.Loupe.desktop";
      in
      {
        "text/html" = browser;
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/about" = browser;
        "x-scheme-handler/unknown" = browser;
        "text/plain" = "code.desktop";
        "application/pdf" = "onlyoffice-desktopeditors.desktop";
      }
      // lib.genAttrs [ "image/png" "image/jpeg" "image/gif" "image/webp" "image/bmp" "image/tiff" "image/svg+xml" "image/avif" ] (_: image);
  };
}
