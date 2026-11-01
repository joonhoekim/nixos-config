{ config, lib, pkgs, user, ... }:

# niri 와 GNOME 옆의 세 번째 세션. 같은 DMS 를 쓴다.
# 전체 그림(왜 Hyprland 인가, 세션, 배치, 심기 규칙): docs/hyprland.md, 셰이더·체인: ./rice/README.md

let
  cfg = config.local.hyprland;
in
{
  options.local.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the Hyprland session. On by default because
        hosts/nixos/common.nix imports this for every host; set to false on a
        machine that should offer niri and GNOME only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;

      # 세션 항목은 hyprland 패키지가 직접 싣는다(programs.uwsm.waylandCompositors 불필요).
      withUWSM = true;
    };

    environment.systemPackages = with pkgs; [
      # hyprctl 로 활성 창 영역을 잡는다 — 맨 `grim -g "$(slurp)"` 로는 안 되는 모드.
      hyprshot

      # 생성된 체인 GLSL 검증용. 하이프랜드는 컴파일 실패해도 hyprctl 이 ok 를 주고
      # 로그도 없이 화면만 검게 된다(0.56.1 실측).
      glslang
    ];

    # wayland-session@….target 에 걸면 순서 고리가 생겨 systemd 가 dms 시작 작업을 조용히 지운다.
    # 서비스에 걸면 고리가 없다. 자세한 고리: docs/hyprland.md
    # 인스턴스 이름 확인: systemctl --user list-units 'wayland-wm@*'
    systemd.user.services = lib.mkIf config.programs.dms-shell.enable {
      dms.wantedBy = [ "wayland-wm@hyprland.desktop.service" ];
    };

    home-manager.users.${user} = { lib, ... }: {
      # DMS 앱 검색은 .desktop 의 Name·GenericName·Keywords 만 본다(Services/AppSearchService.qml).
      # Exec 의 sh 는 $RICE_REPO 폴백용 — .desktop Exec 는 환경 변수를 안 푼다. 따옴표·$ 는 \ 로 가린다.
      xdg.desktopEntries.rice-studio = {
        name = "라이싱 스튜디오";
        genericName = "Rice Studio";
        comment = "화면 셰이더 · 배치 · 장식을 고르고 값을 맞춘다";
        exec = ''sh -c "\"\''${RICE_REPO:-\$HOME/nixos-config}/apps/rice/studio\""'';
        icon = "preferences-desktop-theme";
        terminal = false;
        categories = [ "Settings" "DesktopSettings" ];
        settings.Keywords = "studio;rice;ricing;shader;crt;layout;decor;스튜디오;라이싱;셰이더;배치;장식;";
      };

      home.activation.seedHyprlandRice = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        rice_sync ${./rice/hyprland.lua} "$HOME/.config/hypr/hyprland.lua"

        # rice_ensure 인 이유: 양쪽 다 고친 경우 rice_sync 는 손을 떼서, 다시 로그인하면 장식이 원래대로다.
        # require 가 아니라 dofile 인 이유: require 된 파일은 감시되어 decor.lua 를 쓸 때마다
        # 전체 리로드되고, 리로드는 걸어 둔 화면 셰이더까지 지운다.
        rice_ensure "$HOME/.config/hypr/hyprland.lua" \
          'pcall(dofile, os.getenv("HOME") .. "/.config/hypr/decor.lua")' \
          '-- 장식 값(투명도·흐리게·어둡게·그림자). apps/rice/decor 가 쓴다.'

        # DMS 가 처음 뜨기 전에도 hyprland.lua 의 require 가 찾을 빈 조각.
        rice_sync ${./rice/dms} "$HOME/.config/hypr/dms"

        # 갈래 폴더 하나씩 심는다. 통째로 넘기면 셰이더 한 장만 손봐도 폴더 전체가 멈춰
        # 새 갈래가 영영 안 들어간다(증상: 런처에 crt 하나뿐).
        ${lib.concatMapStringsSep "\n        " (n: ''
          rice_sync ${./rice/shaders}/${n} "$HOME/.config/hypr/shaders/${n}"'')
          (builtins.attrNames (builtins.readDir ./rice/shaders))}

        # 퇴역한 셰이더. rice_sync 는 지우지 않아 스위처에 계속 뜨지만, 손본 값이 있을 수 있어 알리기만 한다.
        for old in crt.frag crt-motion.frag \
                   cyberpunk/rain.frag print/riso.frag print/dither.frag; do
          if [ -f "$HOME/.config/hypr/shaders/$old" ]; then
            echo "note: ~/.config/hypr/shaders/$old 은 퇴역했다. 값을 손봤다면 옮겨 담고 지울 것"
          fi
        done

        # 셰이더와 같은 이유로 파일 하나씩. ~/.config/rice/layout 이 없으면 scrolling 이다.
        ${lib.concatMapStringsSep "\n        " (n: ''
          rice_sync ${./rice/layouts}/${n} "$HOME/.config/hypr/layouts/${n}"'')
          (builtins.attrNames (builtins.readDir ./rice/layouts))}

        rice_sync ${./rice/chains} "$HOME/.config/hypr/chains"

        # 셰이더와 달리 통째로 심는다 — 안의 QML 이 서로 참조해 반쪽만 들어가면 깨진다.
        rice_sync ${./rice/studio} "$HOME/.config/rice-studio"

        # 터미널·런처·GTK 는 ../niri 와 ../../shared/ghostty 가 심는다.
      '';
    };
  };
}
