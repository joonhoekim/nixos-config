{ lib, pkgs, ... }:

# 터치 자세: 화면 키보드, 자동 회전, 태블릿 모드. 컴포지터 쪽은
# modules/nixos/hyprland/rice/hyprland.lua. 전체 그림: docs/galaxy-chromebook-1.md

let
  # mobintl 이 유일하게 패키징된 레이아웃이고 한글 자판은 없다. 키코드만 쏘므로 fcitx5 hangul 이
  # 그대로 받는다. 화면에서 한/영은 Ctrl+space(korean.nix TriggerKeys 의 둘째 항목).
  wvkbdBin = "${pkgs.wvkbd}/bin/wvkbd-mobintl";

  # pygobject3: 가속도계 클레임이 DBus 커넥션에 묶여 셸로는 못 쥔다(./autorotate.py).
  rotatePython = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  # 데몬이 쓰고 autorotate CLI 가 같은 경로를 읽는다. 한쪽만 바꾸면 status 가 늘 "unknown".
  rotateState = "%t/hypr-autorotate.state";

  # 서비스는 늘 떠 있고 신호만 보낸다 — wvkbd 는 시작마다 54 개 레이아웃을 컴파일해 느리다.
  # `status` 는 컴포지터에게 묻는다(`hyprctl layers -j` 의 wvkbd 레이어, 실측). 자판은
  # Mod+B·태블릿 훅·hide 키로 움직여서 따로 적어 둔 상태는 금방 낡는다.
  oskCli = pkgs.writeShellApplication {
    name = "osk";
    runtimeInputs = with pkgs; [ systemd hyprland jq ];
    text = ''
      # pkill 이 아니라 systemctl: 유닛 cgroup 안으로만 간다. SIGRTMIN 도 이름으로 받는다(실측).
      sig() { systemctl --user kill --kill-whom=main --signal="$1" wvkbd.service; }

      visible() {
        [ "$(hyprctl layers -j 2>/dev/null \
          | jq '[.. | objects | select(.namespace? == "wvkbd")] | length')" != "0" ]
      }

      case "''${1:-toggle}" in
        on|show)    sig SIGUSR2 ;;
        off|hide)   sig SIGUSR1 ;;
        toggle)     sig SIGRTMIN ;;
        status)
          if ! systemctl --user is-active --quiet wvkbd.service; then
            echo "off"; exit 1
          fi
          if visible; then echo "on"; else echo "off"; fi
          ;;
        *) echo "usage: osk on|off|toggle|status" >&2; exit 1 ;;
      esac
    '';
  };

  # 기본은 꺼짐이고 켜는 것은 태블릿 모드 훅이다 — 노트북 자세에서 켜 두면 타이핑 중에 화면이 돈다.
  autorotateCli = pkgs.writeShellApplication {
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
  };

  # `tablet-mode enter|leave|status|is-on` — 하이프랜드의 스위치 바인드가 부른다. libinput 의
  # 태블릿 모드 억제는 keyd 가 grab 한 뒤 내보내는 가상 키보드에 안 먹으므로, keyd 아래의
  # 커널 inhibit 로 끊는다. 자세히: docs/galaxy-chromebook-1.md
  tabletModeCli = pkgs.writeShellApplication {
    name = "tablet-mode";
    # 이 셋이 PATH 에 있어야 아래 본문이 서로를 부른다.
    runtimeInputs = [ pkgs.coreutils oskCli autorotateCli ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/tablet-mode.touchpad"

      # 이름으로 sysfs 노드를 찾는다. input 번호는 재열거 때 바뀐다.
      find_dev() {
        for f in /sys/class/input/input*/name; do
          [ "$(cat "$f" 2>/dev/null)" = "$1" ] && { dirname "$f"; return 0; }
        done
        return 1
      }

      inhibit() { # inhibit <이름> <0|1>
        d="$(find_dev "$1")" || { echo "장치 없음: $1" >&2; return 0; }
        echo "$2" | sudo tee "$d/inhibited" >/dev/null
      }

      read_inhibit() {
        d="$(find_dev "$1")" || { echo 0; return; }
        cat "$d/inhibited"
      }

      kbd="AT Translated Set 2 keyboard"
      tpd="Synaptics TM3579-001"

      case "''${1:-}" in
        enter)
          # 손으로 건 `touchpad off`(팬텀 터치용)를 접었다 펴는 것으로 풀지 않게 지금 값을 적어 둔다.
          read_inhibit "$tpd" > "$state"
          inhibit "$tpd" 1
          inhibit "$kbd" 1
          autorotate on
          # 접힌 상태에서는 Mod+B 를 누를 손이 없다.
          osk on
          ;;
        leave)
          inhibit "$kbd" 0
          inhibit "$tpd" "$(cat "$state" 2>/dev/null || echo 0)"
          autorotate off
          osk off
          ;;
        status)
          echo "keyboard inhibited: $(read_inhibit "$kbd")"
          echo "touchpad inhibited: $(read_inhibit "$tpd")"
          echo "autorotate: $(autorotate status)"
          ;;
        # 판정은 키보드 inhibit 로 한다. 스위치는 root 라야 읽히고, 손으로 enter 한 경우엔
        # 스위치가 안 서 있어서 그쪽을 믿으면 UI 가 실제와 어긋난다.
        is-on)
          [ "$(read_inhibit "$kbd")" = "1" ] && echo on || echo off
          ;;
        *) echo "usage: tablet-mode enter|leave|status|is-on" >&2; exit 1 ;;
      esac
    '';
  };

  # `touch-state` — 세 토글의 상태를 JSON 으로. DMS 플러그인이 이것만 불러서 판정이 바뀌어도
  # QML 은 그대로다.
  touchStateCli = pkgs.writeShellApplication {
    name = "touch-state";
    runtimeInputs = [ pkgs.jq oskCli autorotateCli tabletModeCli ];
    text = ''
      # writeShellApplication 은 set -e 라 off 에서 exit 1 하는 CLI 하나가 리포터를 죽이고,
      # 플러그인은 빈 화면을 받는다("조각을 눌러도 아무것도 없다").
      o="$(osk status 2>/dev/null || true)"
      r="$(autorotate status 2>/dev/null || true)"
      t="$(tablet-mode is-on 2>/dev/null || true)"

      jq -nc \
        --arg osk "''${o:-off}" \
        --arg rotate "''${r:-off}" \
        --arg tablet "''${t:-off}" \
        '{ osk: $osk, rotate: $rotate, tablet: $tablet }'
    '';
  };
in
{
  # 위 CLI 를 손가락으로 부르는 유일한 길이라 CLI 를 까는 이 파일에서 켠다 — 따로 놀면
  # "단추는 있는데 눌러도 아무 일도 없다" 가 된다.
  local.dms.touchControls.enable = true;

  environment.systemPackages = [
    pkgs.wvkbd
    oskCli
    autorotateCli
    tabletModeCli
    touchStateCli
  ];

  # 숨긴 채로 떠 있다가 신호를 받는다. --auto 는 zwp_input_method_v2 를 fcitx5 와 다투고
  # 지는 쪽이 조용히 진다(한글 입력이 걸린다). 자세히: docs/galaxy-chromebook-1.md
  systemd.user.services.wvkbd = {
    description = "wvkbd on-screen keyboard (hidden until signalled)";

    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    # GNOME 세션에는 자기 화면 키보드가 있어서 graphical-session.target 이 아니라 컴포지터에 건다.
    wantedBy = [ "niri.service" "wayland-wm@hyprland.desktop.service" ];

    serviceConfig = {
      # -L 가로, -H 세로 높이. 260 은 1920x1080 의 24% 로 네 줄 자판이 손가락에 맞는 최소치쯤,
      # 세로(1080x1920)는 같은 비율이 훨씬 커서 340 을 따로 준다.
      ExecStart = "${wvkbdBin} --hidden -L 260 -H 340";
      Restart = "on-failure";
    };
  };

  # 꺼진 채로 떠 있다가 신호를 받는다. iio-hyprland 가 아닌 이유는 ./autorotate.py 머리말.
  systemd.user.services.hypr-autorotate = {
    description = "Rotate Hyprland output and touch input from the accelerometer";

    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "niri.service" "wayland-wm@hyprland.desktop.service" ];

    # 유닛 환경에는 PATH 가 없고, 이 서비스는 hyprctl 을 부른다.
    path = [ pkgs.hyprland ];

    serviceConfig = {
      ExecStart = "${rotatePython}/bin/python3 ${./autorotate.py} ${rotateState}";
      Restart = "on-failure";
    };
  };
}
