{ config, lib, pkgs, user, ... }:

# DankMaterialShell 이 도는 niri 세션. GNOME 은 tuigreet 의 대피로로 남는다.
# 설치는 선언적이고 라이싱은 아니다 — 설정은 $HOME 에 심는 쓰기 가능한 파일이다.
# 전체 그림(왜 flake·HM settings 를 안 쓰는가, 심기 규칙): docs/niri.md

let
  cfg = config.local.niri;

  # 처음 심을 것일 뿐이고 그 뒤는 apps/rice/switch 가 정한다. 옵션이면 선언적이라는 뜻이 되어 안 둔다.
  seedProfile = "amoled";
in
{
  options.local.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the niri session. On by default because hosts/nixos/common.nix
        imports this for every host; set to false on a machine that should stay
        GNOME-only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # xdg.portal.config.niri = gnome+gtk 도 선언한다. 데스크톱별 이름공간이라 GNOME 포털과 안 부딪힌다.
    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      # $PATH 에 있으면 니리가 필요할 때 띄운다. 없으면 X11 클라이언트가 붙을 디스플레이가 없다.
      xwayland-satellite

      # 셸이 안 뜰 때 쓰는 Mod+D 폴백 런처.
      fuzzel
    ];

    # home.file 이 아닌 이유: 읽기 전용 심링크면 니리를 rebuild 없이 못 고치고, DMS 는 원자적으로 써서
    # (Common/SettingsData.qml) 첫 저장에 심링크를 갈아치운다. linkGeneration 뒤라야 HM 이 옛 심링크를 지운 뒤 복사된다.
    home-manager.users.${user} = { lib, ... }: {
      home.activation.seedNiriRice = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        rice_sync ${./rice/config.kdl} "$HOME/.config/niri/config.kdl"

        # 지우면 니리 기본 애니메이션으로 돌아간다.
        rice_sync ${./rice/animations.kdl} "$HOME/.config/niri/animations.kdl"
        rice_ensure "$HOME/.config/niri/config.kdl" 'include "animations.kdl" optional=true' \
          '// 창 열림/닫힘 셰이더. 파일을 지우면 니리 기본 애니메이션으로 돌아간다.'

        rice_sync ${./rice/profiles} "$HOME/.config/rice/profiles"

        # 새 머신이 반쯤 걸린 룩이 아니라 일관된 룩으로 뜨게 프로필 조각도 심는다.
        rice_sync ${./rice/profiles/${seedProfile}/niri.kdl} "$HOME/.config/niri/profile.kdl"
        rice_sync ${pkgs.writeText "rice-current" seedProfile} "$HOME/.config/rice/current"

        # 터미널(ghostty)은 ../../shared/ghostty 가 심는다(macOS 와 같은 파일). 색은 matugen 이 쓴다.

        # 색과 lines/radius 는 apps/rice/fuzzel 이 dank-rice.ini 에 쓴다. include 줄을 여기서 붙이는 건
        # fuzzel 이 절대 경로만 받아서이고, 첫 로그인에 기본 테마(솔라라이즈드 라이트)로 안 뜨게 하려는 것이다.
        rice_sync ${pkgs.writeText "fuzzel.ini" (''
          # apps/rice/fuzzel 이 쓰는 색 파일. 기본 섹션이어야 해서 맨 위다.
          include=/home/${user}/.config/fuzzel/dank-rice.ini

        '' + builtins.readFile ./rice/fuzzel.ini)} "$HOME/.config/fuzzel/fuzzel.ini"
        rice_sync ${./rice/fuzzel-fallback.ini} "$HOME/.config/fuzzel/dank-rice.ini"

        # DMS 가 제자리에서 고치는 파일이다(rice/gtk-settings.ini). 니리에는 XSettings 데몬이 없어 GTK 가 이 파일을 읽는다.
        rice_sync ${./rice/gtk-settings.ini} "$HOME/.config/gtk-3.0/settings.ini"
        rice_sync ${./rice/gtk-settings.ini} "$HOME/.config/gtk-4.0/settings.ini"
      '';
    };

    programs.dms-shell = {
      enable = true;

      # NixOS 는 유닛 자신의 WantedBy=graphical-session.target 을 무시하므로 이 값이 DMS 를 GNOME 밖에 둔다
      # (빌드된 시스템에서 niri.service.wants/dms.service 만 있음을 확인).
      systemd.target = "niri.service";
    };
  };
}
