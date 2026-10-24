# macOS 라이싱 — 구성과 결정

`modules/darwin/rice` 가 무엇을 하고, 왜 지금 모양인지를 적는다. 코드 주석에는
그 줄이 없으면 무엇이 깨지는지만 남기고, 고른 이유와 버린 대안은 여기에 둔다.

## 구성

| 조각 | 하는 일 | 자리 |
|---|---|---|
| rift-grid | 타일링 WM, 창 테두리, 메뉴 바 워크스페이스 표시 | `apps/rift-grid`(빌드·서명), `hosts/darwin/common.nix`(로그인 에이전트), `rice/rift/config.toml`(설정 시드) |
| wal-watch | 벽지가 바뀌면 `apps/rice/colors` 를 부른다 | `rice/default.nix` 의 `launchd.user.agents.wal-watch` |
| `apps/rice/colors` | pywal 로 팔레트를 뽑아 rift 테두리 색 두 줄을 다시 쓴다 | — |
| wezterm | `~/.cache/wal/colors.json` 을 직접 읽고 감시한다 | `rice/wezterm/wezterm.lua` |
| LinearMouse | 마우스 휠 방향만 뒤집는다 | `rice/linearmouse/` (README 에 근거) |
| `rice/bin` | rift 키바인딩이 부르는 스크립트(monocle.sh) | `~/.config/rice/bin` 으로 시드 |

설정 파일은 스토어 심링크가 아니라 **시드**다. `rice_sync`(`modules/shared/rice-seed-helpers.nix`)가
없을 때와 손대지 않았을 때만 심고, 심은 뒤에는 `~/.config` 쪽이 원본이다. 되받기는
`apps/rice/save`, 밀어 넣기는 `apps/rice/restore`. rift 의 "settings" 메뉴가 설정 파일을 에디터로
열기 때문에 읽기 전용 심링크로는 쓸 수 없다.

터미널 팔레트(ghostty)는 이 흐름에 넣지 않는다. 그쪽은 `modules/shared/ghostty` +
`apps/rice/term` 이 따로 정하고, 생성기 둘이 같은 테마 파일을 쓰면 다음 switch 에서 한쪽으로
되돌아간다.

## 상태 바를 두지 않는다

sketchybar 를 2026-08-05 까지 썼다. 그리던 여섯 가지 중 다섯(시계, 배터리, CPU, 입력 소스,
포커스된 앱)은 macOS 메뉴 바에 이미 있었고, 없는 것은 rift 워크스페이스 표시 하나였다. 그건
이제 rift 가 직접 그린다(`[settings.ui.menu_bar]`). 프로세스도 TCC 허가도 더 필요 없다.

메뉴 바 전체를 sketchybar 로 바꾸는 쪽은 안 된다. 메뉴 엑스트라를 alias 로 띄우면 그림은
나오지만(확인함) 클릭하려면 손쉬운 사용 헬퍼가 따로 필요하고, 왼쪽의 앱 메뉴는 alias 로도
옮길 수 없다. ad-hoc 서명된 스토어 바이너리에 TCC 허가 둘을 걸어 macOS 가 그냥 주는 것을
흉내 내는 셈이다. 설정은 `git log -- modules/darwin/rice/sketchybar` 에 있다.

바가 있던 때는 위쪽 바깥 gap 이 38 이었다(32pt 바 + 6). 지금은 네 방향 모두 6.

## 창 테두리

rift-grid 가 그린다(`[settings.ui.borders]`). 그 전에는 JankyBorders 를 rift 의 자식 프로세스로
띄웠다 — `ax_focus` 모드가 rift 의 손쉬운 사용 허가를 물려받게 하려고. 배선은
`git log -- modules/darwin/rice/borders`.

## 키맵의 계보

niri 세션(`modules/nixos/niri/rice/config.kdl`) → AeroSpace → rift 순으로 옮겨 왔고, 지금 기준은
subline 의 "ijkl" 프리셋이다(`docs/keymap.md`). Alt(⌥)가 niri 의 Mod 자리다.

AeroSpace 에서 옮길 때 빠진 것:

- `mode service` / `mode main`. rift 에는 모달 바인딩이 없다. 쓸모 있던 것(reload_config,
  unjoin_windows)은 직접 바인딩으로 옮겼다.
- `balance-sizes` (alt-r). 같은 명령이 없다. Alt+R 은 지금 monocle 토글이다.
- `macos-native-fullscreen`. rift 는 자기 전체 화면만 한다. 네이티브 전체 화면은 어느 앱에서나
  Ctrl+Cmd+F.
- `move-workspace-to-monitor`. rift 는 워크스페이스가 아니라 창을 디스플레이 사이로 옮긴다.

그 뒤에 바꾼 것:

- **Alt+Ctrl 계층.** 한때 Alt+Ctrl 이 move_node 바인딩을 전부 한 번 더 받았다(같은 동작에
  철자 둘). 그러자 디스플레이 이동을 놓을 자리가 없어서 중복을 지우고 Alt+Ctrl 을 "디스플레이·
  그리드를 건넌다, WM 에 닿는다"로 정했다.
- **Alt+F / Alt+Shift+F.** 처음에는 hyprland·niri 와 반대였다. 지금은 맨 키가 gap 을 남기는
  전체 화면, Shift 가 화면 전체를 덮는 쪽이다.
- **join.** 네 방향 `join_window` + `unjoin_windows` 다섯 키를 `consume_or_expel_window` 하나로
  접었다. 네 방향이 쓰던 Alt+Shift+방향키는 창 이동이 가져갔다.
- **Alt+Comma.** 스택 토글에서 rift 설정 창으로 바뀌었다(subline 의 Mod+Comma). 스택 토글은
  Alt+Shift+Comma.

## 키맵 치트시트를 오버레이로 만들지 않았다

리눅스에서는 DMS 가 돌고 있는 컴포지터에 바인딩을 물어 오버레이를 그린다. macOS 에서
만들어 봤다가 버렸다. 설정은 `rift-grid-cli execute config get` 으로 쉽게 읽히지만, 그 창을 rift
규칙으로 골라낼 수가 없다 — Ghostty 는 AXTitle 을 내놓지 않고, `rift-grid-cli query windows`
의 id 는 금방 사라져서 밖에서 추적하려면 폴링과 재시도가 필요하다. 그래서 Alt+Shift+/ 는
`docs/keymap.md` 를 연다.
