# NixOS 공통 설정 (hosts/nixos/common.nix)

`hosts/nixos/common.nix` 는 모든 NixOS 호스트가 import 하는 하드웨어 무관 설정이다. 이 문서는 그 안에서
"왜 이렇게 했는지"가 코드만으로 안 읽히는 블록들을 설명한다. 호스트별 사정은 [`hosts/`](hosts/) 와
[galaxy-chromebook-1](galaxy-chromebook-1.md).

## nix.nixPath 를 두지 않는 이유

NIX_PATH 는 `<nixpkgs>` 같은 꺾쇠 경로를 푸는 검색 경로다(옛 `nix-shell -p`, `nix-build '<nixpkgs>'` 가 쓴다).
`hosts/nixos/common.nix` 는 `nix.nixPath` 를 일부러 정의하지 않는다.

- nixpkgs 의 `nixos/modules/misc/nixpkgs-flake.nix` 는 flake 로 빌드한 모든 시스템에
  `nix.nixPath = lib.mkDefault [ "nixpkgs=flake:nixpkgs" ... ];` 를 준다.
- `mkDefault` 는 어떤 평범한 정의에도 진다. 그래서 `nixPath` 를 한 줄이라도 적으면 `nixpkgs=` 가 NIX_PATH 에서
  조용히 빠지고, `nix-shell -p foo` / `nix-build '<nixpkgs>' -A hello` 가 "file 'nixpkgs' was not found in the
  Nix search path" 로 실패한다.
- `nix run nixpkgs#hello` 는 그래도 돈다. 그쪽은 같은 모듈이 따로 설정하는 `nix.registry` 를 타서, 증상이 반쪽만
  보인다.

`nixos-config=` 항목도 넣지 않는다. 동작하는 값이 있을 수 없다:

- `<nixos-config>` 는 파일을 원한다(디렉토리면 `default.nix` 가 있어야 하는데 저장소 루트에는 `flake.nix` 뿐이다).
- 호스트의 `default.nix` 를 가리켜도 평가되지 않는다. `common.nix` 는 `home-manager` 를 specialArgs 에서 받는데,
  그건 flake 안에서만 있다.

## 로그인 화면(greetd)과 세션

greetd 는 로그인 화면(그리터)을 띄우는 작은 데몬이고 GDM 을 대신한다. 로그인 화면 뒤에서 gnome-shell·
gnome-session 같은 GNOME 스택이 돌지 않는다.

- 실제 그리터는 subline 의 것이다(`modules/nixos/subline`, `subline --greeter`, [subline](subline.md)).
  `common.nix` 에 적힌 tuigreet(텍스트 그리터)는 **대체용**이라 `mkDefault` 로 둔다. `local.subline.greeter` 가 켜져
  있는 동안 subline 모듈이 command 와 `useTextGreeter` 를 덮어쓰고, 끄면 다른 변경 없이 tuigreet 가 돌아온다.
- 두 그리터 모두 GDM 이 쓰던 `sessionData.desktops` 를 읽으므로 세션 항목이 다 보인다. `gnome.desktop` 은
  `desktopManager.gnome.enable`, `niri.desktop` 은 `programs.niri.enable`, `hyprland{,-uwsm}.desktop` 은
  `programs.hyprland.enable`(패키지가 둘 다 주고 uwsm 쪽을 쓴다 — [hyprland](hyprland.md)), `subline.desktop` 은
  `programs.subline.enable` 에서 온다.
- `useTextGreeter` 는 유닛의 stdio 를 /dev/tty1 로 돌려(TTYReset, VHangup, VTDisallocate) 커널·부팅 메시지가 TUI
  위에 찍히지 않게 한다. 텍스트 그리터 전용이고, DRM 컴포지터를 그리터로 쓸 때는 꺼야 한다.
- tuigreet 의 `--remember` 는 마지막 사용자 이름을, `--remember-session` 은 마지막으로 띄운 세션을 채운다.

`displayManager.defaultSession` 은 `services/display-managers/default.nix` 의 assertion 이
`sessionData.sessionNames`("gnome" | "niri" | "hyprland" | "hyprland-uwsm" | "subline") 중 하나이기를 요구한다.
subline 이 깔리면 `modules/nixos/subline` 이 "subline" 으로, 아니면 "niri" 로 떨어진다. 다만 두 그리터 모두 이
값을 읽지 않는다. 두 번째 로그인부터는 tuigreet 의 `--remember-session` 과 subline 이 기억한 마지막 선택이 정한다.

### 키링

greetd 의 PAM 서비스는 `auth substack login` + `session include login` 이라 /etc/pam.d/login 을 통째로 물려받고,
그 스택에 이미 pam_gnome_keyring 의 auth·session 규칙이 있다. 그래서 GDM 없이도 gnome-keyring 이 로그인 때 풀린다.
`security.pam.services.greetd.enableGnomeKeyring` 은 여기서 아무 일도 안 한다. greetd 서비스는
`useDefaultRules = false` 이고, 생성되는 키링 규칙이 바로 그 블록에 들어 있다.

GNOME 세션은 기본이 아니지만 남겨 둔다. niri/Quickshell 갱신이 데스크톱을 깨뜨릴 때의 대체 세션이고, 저장소에서
gnome-keyring 과 seahorse 를 끌어오는 유일한 줄이다.

## smartd 경보가 데스크톱까지 오는 길

smartd(드라이브 SMART 감시 데몬) 자체는 호스트마다 켠다([mn56](hosts/mn56.md), [evo-t1](hosts/evo-t1.md) — 거기에
common.nix 에 못 두는 이유가 있다). 경보를 **어떻게 전하는지**는 호스트별 문제가 아니라서 `common.nix` 에서 한 번
정하고, 데몬을 돌리는 호스트에 다 적용된다.

- **x11 은 끈다.** 이 옵션은 `services.xserver.enable` 이 켜져 있으면(Xwayland·xkb 때문에 켜 둔다) 기본으로
  켜지고 DISPLAY=:0 을 박는다. 이 기계들의 세션은 전부 Wayland 라 :0 은 잘해야 어떤 Xwayland 이고 아니면 아무것도
  없다. 거기로 간 경보는 사라진다.
- **systembus-notify 가 대신 나른다.** smartd 는 root 로 돌고 데스크톱 알림은 사용자별이라 그 경계를 넘어야 한다.
  이걸 켜면 smartd 모듈이 `services.systembus-notify` 도 `mkDefault` 로 켠다. 그 모듈은 로컬 사용자 누구나 세션에
  알림을 쏠 수 있게 된다고 경고한다. 1인 데스크톱에서는 무관하지만 사용자가 늘면 다시 본다.
- **wall 은 그 아래 대체로 남긴다.** 세션이 없어도 TTY 에 닿으므로 데스크톱 자체가 고장 났을 때도 보인다.

처음 켜는 rebuild 의 함정: 사용자 유닛은 `wantedBy=graphical-session.target` 인데, 이미 active 인 타깃은 새로 깔린
wants 를 시작하지 않는다. 그래서 switch 가 성공해도 다음 로그인(또는 `systemctl --user start systembus-notify`)까지
inactive 로 남는다.

검증: 생성된 smartd-notify.sh 를 root 로, SMARTD_DEVICESTRING/SMARTD_MESSAGE 를 넣고 손으로 돌리면 신호가 시스템
버스를 건너 데스크톱에 알림이 뜬다.

## 세션 버스(dbus-broker)를 activation 이 재시작하지 않게 하는 이유

dbus-broker 는 D-Bus 메시지 버스의 구현체이고, 사용자 세션마다 하나씩 돈다. 생성되는 사용자 dbus-broker 유닛에는
스토어 경로(PATH, LOCALE_ARCHIVE, TZDIR, X-Restart-Triggers)가 들어 있어서 nixpkgs 를 올릴 때마다 거의 매번 바뀐
것으로 표시된다. 그런데 switch-to-configuration 은 바로 그 버스로 사용자 매니저와 말하고
(`LocalConnection::new_session()`), 작업의 JobRemoved 신호를 타임아웃 없는 루프에서 기다린다. 브로커를 재시작하면
그 연결이 끊겨 신호가 오지 않고, `nixos-rebuild switch` 가 "restarting the following user units:
dbus-broker.service" 에서 멈춘다.

- `restartIfChanged = false`(X-RestartIfChanged=false)는 이 유닛을 건너뛰는 목록("NOT restarting the following
  user units: ...")으로 옮긴다. 돌고 있는 버스는 다음 로그인까지 옛 환경을 유지하고, 상류도 그걸 원한다 —
  `nixos/modules/services/system/dbus.nix`: "Don't restart dbus. Bad things tend to happen if we do."
- `reloadIfChanged` 도 꺼야 하고 `mkForce` 가 필요하다. dbus.nix 가 true 로 두고, `systemd-lib.nix` 가 둘을
  if/else 사슬로 내보내서 X-ReloadIfChanged 가 이기면 X-RestartIfChanged 는 아예 쓰이지 않는다.
- 대가: rebuild 때 사용자 버스가 새 D-Bus 서비스·활성화 파일을 집어 오지 않는다. 다시 로그인하면 된다.

## zram 에 맞춘 VM 조정과 디스크 스왑 순서

zram 은 RAM 안에 압축 블록 장치를 만들어 스왑으로 쓰는 것이다. 커널 기본값 둘 다 스왑이 느린 회전 디스크라고
가정하는데, zram 은 정확히 그 반대다.

- **swappiness 60 → 180**: 기본값은 스왑아웃 하나가 탐색 한 번이던 시절의 배급이다. zram 페이지아웃은 RAM 속도의
  zstd 압축이라 익명 페이지를 페이지 캐시와 바꾸는 것이 거의 공짜이고, 압박 때 커널이 **먼저** 고를 수단이어야
  한다. 상한은 200(커널 5.8 에서 바로 이 경우를 위해 100 에서 올렸다).
- **page-cluster 3 → 0**: 3 은 스왑인마다 2^3 = 8 페이지를 읽는다는 뜻이다. 미리 읽기는 디스크의 탐색 지연을 나누는
  것인데 zram 에는 탐색이 없어서, 나머지 7 페이지는 대개 쓰이지 않는 압축 해제 7 번이다.

디스크 스왑 파티션도 선언한 호스트는 순서가 저절로 맞는다. zram0 은 priority 5, 파티션은 -1 이라 zram 이 늘 먼저
차고 디스크는 zram 이 다 찬 뒤에만 쓰인다. 디스크는 첫 정거장이 아니라 받침이다(mn56 의 파티션은 hibernate 이미지
자리이기도 하다 — [mn56](hosts/mn56.md)).
