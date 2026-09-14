{ pkgs, ... }:

# 이 섀시의 터치 자세를 세우는 것들. 화면 키보드, 자동 회전, 태블릿 모드.
# ./hardware.nix 가 "이 하드웨어가 이래서 이 줄이 있다" 면 여기는 "이 하드웨어로
# 뭘 하겠다" 쪽이라 파일을 갈랐다.
#
# 레포에서 터치스크린이 있는 머신은 여기뿐이다. 컴포지터 쪽 설정은 그래도
# ../../../modules/nixos/hyprland/rice/hyprland.lua 에 있는데, 그쪽은 라이싱
# 파일이라 호스트별로 가를 수단이 없기 때문이다 — 터치 장치가 없는 머신에서
# 무해하게 죽는 줄들이라 그대로 뒀다.

let
  # wvkbd 는 레이아웃을 컴파일 타임에 박아 넣는다. mobintl 이 유일하게 패키징된
  # 묶음이고(deskintl 은 nixpkgs 에 없다), 그 안에 한글 자판은 없다.
  #
  # 없어도 된다. wvkbd 는 virtual-keyboard-v1 로 **키코드**를 쏘고, fcitx5 는
  # 그 위에서 텍스트를 받으므로 물리 키보드로 친 것과 구분하지 않는다. 두벌식
  # 변환은 ../../../modules/nixos/korean.nix 의 hangul 엔진이 그대로 한다.
  # 화면에서 한/영을 치는 방법은 **Ctrl+space** 다 — 그쪽 Hotkey/TriggerKeys 의
  # 두 번째 항목이고, 첫 번째(Hangul keysym)는 이 자판에 키가 없다.
  osk = "${pkgs.wvkbd}/bin/wvkbd-mobintl";

  # ./autorotate.py 를 돌릴 파이썬. pygobject3 는 GDBus 때문에 필요하다 —
  # 가속도계 클레임이 DBus 커넥션에 묶여 있어서 셸로는 못 쥔다(그 파일 머리말).
  rotatePython = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  # 두 데몬이 상태를 적어 두는 자리. CLI 의 `status` 가 읽는다.
  rotateState = "%t/hypr-autorotate.state";
in
{
  environment.systemPackages = with pkgs; [
    wvkbd

    # `osk on|off|toggle` — 화면 키보드를 보이고 감춘다.
    #
    # 서비스는 계속 떠 있고 이 명령은 신호만 보낸다. 띄웠다 죽였다 하지 않는
    # 것은 wvkbd 가 시작할 때 54 개 레이아웃을 컴파일하기 때문이다 — 누를 때마다
    # 그 값을 내면 손가락으로 쓰기엔 느리다.
    #
    # 상태를 못 읽는 것이 이 물건의 한계다. wvkbd 는 자기가 보이는지 알려주지
    # 않으므로 `status` 는 **서비스가 도는지**만 답한다. 확실한 상태가 필요한
    # 쪽(./touch.nix 의 태블릿 모드 훅)은 toggle 이 아니라 on/off 를 쓴다.
    (pkgs.writeShellApplication {
      name = "osk";
      runtimeInputs = with pkgs; [ systemd ];
      text = ''
        # pkill 이 아니라 systemctl 로 쏜다. 유닛의 cgroup 안으로만 가므로
        # 이름이 겹치는 남의 프로세스를 때릴 일이 없다. SIGRTMIN 도 이름으로
        # 받는다(실측).
        sig() { systemctl --user kill --kill-whom=main --signal="$1" wvkbd.service; }

        case "''${1:-toggle}" in
          on|show)    sig SIGUSR2 ;;
          off|hide)   sig SIGUSR1 ;;
          toggle)     sig SIGRTMIN ;;
          status)
            if systemctl --user is-active --quiet wvkbd.service; then
              echo "osk: 서비스 동작 중 (보이는지는 알 수 없다)"
            else
              echo "osk: 서비스 꺼짐"
              exit 1
            fi
            ;;
          *) echo "usage: osk on|off|toggle|status" >&2; exit 1 ;;
        esac
      '';
    })

    # `autorotate on|off|toggle|status` — 화면 자동 회전.
    #
    # 기본값은 꺼짐이고, 켜는 것은 아래 태블릿 모드 훅이다. 노트북 자세에서
    # 켜 두면 책상에서 타이핑하다 화면이 돌아간다 — 접었을 때만 원하는 동작이다.
    #
    # 신호 규약은 위 `osk` 와 같게 맞췄다. 데몬이 상태를 파일에 적으므로
    # status 는 osk 와 달리 실제 상태를 답한다.
    (pkgs.writeShellApplication {
      name = "autorotate";
      runtimeInputs = with pkgs; [ coreutils systemd ];
      text = ''
        state="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-autorotate.state"

        sig() {
          systemctl --user kill --kill-whom=main --signal="$1" hypr-autorotate.service
        }

        case "''${1:-status}" in
          on)     sig SIGUSR2 ;;
          off)    sig SIGUSR1 ;;
          # osk 와 달리 토글 신호가 없다 — GLib 이 SIGRTMIN 을 안 받는다
          # (./autorotate.py 의 신호 블록). 데몬이 쓴 상태를 읽어서 가른다.
          toggle)
            if [ "$(cat "$state" 2>/dev/null)" = "on" ]; then
              sig SIGUSR1
            else
              sig SIGUSR2
            fi
            ;;
          status) cat "$state" 2>/dev/null || { echo "unknown"; exit 1; } ;;
          *) echo "usage: autorotate on|off|toggle|status" >&2; exit 1 ;;
        esac
      '';
    })
  ];

  # 화면 키보드. 숨긴 채로 떠 있다가 신호를 받으면 나타난다.
  #
  # ── 왜 --auto 를 안 쓰는가 ────────────────────────────────────────────────
  # wvkbd 에는 텍스트 필드에 포커스가 가면 저절로 뜨는 --auto 가 있고, 터치
  # 머신에서 제일 갖고 싶은 동작이 그것이다. 그런데 그 기능은
  # zwp_input_method_v2 로 구현돼 있고, **그 자리는 fcitx5 가 이미 잡고 있다**
  # (korean.nix 의 waylandFrontend = true). 한 시트에 input method 는 하나다.
  #
  #   wayland-info | grep input_method
  #   #  interface: 'zwp_input_method_manager_v2', version: 1, name: 28
  #
  # 둘이 다투면 지는 쪽이 조용히 진다. 한글 입력은 이 머신에서 제일 비싼 축이라
  # (postmortems/2026-08-05-vscode-terminal-hangul.md) 그걸 걸고 자동 표시를
  # 사는 거래는 안 한다. 여기서 쓰는 virtual-keyboard-v1 경로는 덧붙이기만 하는
  # 것이라 fcitx5 와 겹치지 않는다.
  #
  # 자동 표시가 필요하면 태블릿 모드 훅이 대신한다 — 화면을 접으면 뜬다.
  systemd.user.services.wvkbd = {
    description = "wvkbd on-screen keyboard (hidden until signalled)";

    # 로그아웃 때 같이 내려간다. dms.service 와 같은 모양이다.
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    # graphical-session.target 이 아니라 컴포지터 유닛에 건다. 저 타깃에 걸면
    # GNOME 세션에서도 뜨는데, 그쪽은 자기 화면 키보드가 따로 있다.
    wantedBy = [ "niri.service" "wayland-wm@hyprland.desktop.service" ];

    serviceConfig = {
      # -L 은 가로 모드 높이, -H 는 세로 모드 높이다. 1920x1080 에서 260 은
      # 화면의 24% 로, 네 줄 자판이 손가락에 맞는 최소치쯤 된다. 세로로 돌리면
      # (1080x1920) 같은 비율이 훨씬 큰 픽셀이라 340 을 따로 준다.
      ExecStart = "${osk} --hidden -L 260 -H 340";
      Restart = "on-failure";
    };
  };

  # 화면 자동 회전. 꺼진 채로 떠 있다가 신호를 받는다 — 왜 켠 채로 두지 않는지,
  # 왜 nixpkgs 의 iio-hyprland 가 아닌지는 ./autorotate.py 머리말.
  systemd.user.services.hypr-autorotate = {
    description = "Rotate Hyprland output and touch input from the accelerometer";

    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "niri.service" "wayland-wm@hyprland.desktop.service" ];

    # hyprctl 은 이 서비스가 부르는 것이고, 유닛 환경에는 PATH 가 없다.
    path = [ pkgs.hyprland ];

    serviceConfig = {
      # %t 는 $XDG_RUNTIME_DIR 이다. autorotate CLI 의 `status` 가 같은 자리를
      # 읽는다 — 한쪽만 고치면 상태가 영원히 "unknown" 이 되므로 같이 고칠 것.
      ExecStart = "${rotatePython}/bin/python3 ${./autorotate.py} ${rotateState}";
      Restart = "on-failure";
    };
  };

  # ── 창이 안 밀린다 ────────────────────────────────────────────────────────
  # wvkbd 는 overlay 레이어에 exclusive zone 없이 뜬다(`hyprctl layers` 로
  # 확인: `namespace: wvkbd`, `Layer level 3 (overlay)`). 즉 자판이 창 위를
  # 덮을 뿐 창을 밀어 올리지 않아서, 화면 아래쪽 입력란은 자판에 가린다.
  # 상류가 그렇게 만든 것이고 옵션으로 못 바꾼다.
}
