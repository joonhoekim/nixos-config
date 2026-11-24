# subline 세션 — 세션과 로그인 화면

subline 은 `~/git/subline` 에서 개발하는 터치 우선 Wayland 컴포지터다. `modules/nixos/subline` 이 이걸 모든 NixOS 호스트의
유일한 세션이자 greetd 로그인 화면으로 쓴다. 같은 이름의 터미널 앱은 [subline-terminal.md](subline-terminal.md).

## 무엇을 누가 배선하나

subline 은 자기 NixOS 모듈을 싣는다(그 레포의 nix/module.nix, flake 입력 `subline`). 세션 배선은 그 모듈이 한다:

- 패키지와 xwayland-satellite, wayland-sessions 항목
- 포털: gtk + gnome-keyring + 스크린숏/화면 공유용 wlr + subline 자체
- XDG_CURRENT_DESKTOP=subline 에서만 도는 mate-polkit 에이전트
- 잠금 화면용 PAM 서비스
- `greeter` 로 greetd 자체(명령, 텍스트 그리터 TTY 처리 없음, 마지막 사용자·세션을 기억하는 홈)

이 레포 모듈은 켜기만 하고 기본 세션과 대피 그리터만 정한다. 데스크톱 환경 모듈이 켜 주던 기반(키링, 블루투스,
upower, udisks2, gsettings 스키마 등)은 `modules/nixos/desktop.nix` 가 직접 켠다.

## 올리기

`nix run .#subline-update`(apps/subline-update) — 입력을 올리고, 전환하고, 돌고 있는 세션을 새 빌드로 제자리 재시작하고,
flake.lock 을 커밋한다. 로그인 화면은 다음에 뜰 때 새 빌드가 된다.

## 세션

세션은 subline 하나다. 스트립·독·화면 키보드·알림·잠금 화면을 subline 이 직접 가져온다.

`services.displayManager.defaultSession` 값은 sessionData.sessionNames 중 하나여야 하고 "subline" 은 패키지의
passthru.providedSessions 로 들어 있다([nixos-common](nixos-common.md#로그인-화면greetd과-세션)).

## 로그인 화면이 안 뜰 때

greetd 유닛은 Restart=on-success 라 그리터가 죽으면 루프가 아니라 VT1 이 어둡다. Ctrl+Alt+F2 로 텍스트 로그인한 뒤 셋
중 하나:

- `local.subline.greeter = false;` — 다음 rebuild 에 tuigreet 가 돌아온다
- `nix run .#rollback`
- 부팅 메뉴의 이전 세대

## 설정은 사용자 것

`~/.config/subline/config.toml` 을 핫 리로드하고 설정 앱(subline-settings)이 쓴다. 아직 레포에서 심는 것이 없다(rice/
없음). 필요해지면 rice_sync 로 심는다([rice-seeding](rice-seeding.md)).
