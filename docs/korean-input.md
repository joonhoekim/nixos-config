# 한국어 입력 (NixOS)

`modules/nixos/korean.nix` 는 NixOS 쪽 로케일과 리눅스 전용 폰트를 맡는다. 입력기 패키지는 없다: 한글은 subline 의
내장 입력기가 조합하고(`keyboard.input_method`, 기본값 `auto` 는 외부 입력기가 없으면 내장을 쓴다), 한/영 키는
kanata(evdev 에서 키를 리맵하는 데몬)가 만든다. 공통 폰트는 [fonts.md](fonts.md).

## 로케일

UI 는 en_US, 지역 포맷은 ko_KR. LC_TIME 만 en_DK.UTF-8 이다. ko_KR 이면 날짜를 그리는 모든 것이 한국어가 된다 —
`date` 가 "2026. 08. 01. (토)", 시계가 영어 라벨 옆에 토 / 오후(요일 이름과 12/24시간 선택이 이 범주에서
온다). en_DK 는 영어 로케일(Sat, August)이면서 LC_TIME 이 ISO 8601 이다 — d_fmt "%Y-%m-%d", t_fmt "%T", am_pm 비어
있음. i18n.supportedLocales 는 defaultLocale 과 이 값들의 합집합이 기본이다.

## 한/영 키가 지나는 길

Right Alt → Hangul 리맵은 `modules/nixos/kanata.nix` 의 kanata 가 한다(머신당 설정 하나, 같은 설정이 Caps 레이어도
건다 — [keymap.md](keymap.md)). galaxy-chromebook-1 만 kanata 를 끄고 subline 의 xkb 옵션 `korean:ralt_hangul` 로
같은 keysym 을 낸다([galaxy-chromebook-1](galaxy-chromebook-1.md)). 세 키코드 이름공간을 건너며 이름이 매번 다르다:

```
kanata `ralt hngl` (deflocalkeys-linux hngl 122)  ->  evdev KEY_HANGEUL (122)
  -> xkb <HNGL>, keycode 130 (evdev + 8)
  -> keysym `Hangul` (`xkbcli compile-keymap --layout us | grep HNGL` 로 확인)
  -> subline 내장 입력기가 영문 <-> 한글을 토글
```

확인: 첫 홉은 kanata 의 가상 키보드 장치에 `sudo evtest`, 둘째·셋째는 `wev` 가 보여 주는 keycode 와 keysym 이다.

## NIXOS_OZONE_WL

nixpkgs 는 Electron/Chromium 의 Wayland IME 플래그를 이 세션 변수 뒤에 둔다:
`${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}`.
변수가 없으면 VS Code 는 네이티브 Wayland 창인데 이 플래그는 하나도 없다. 변수를 켜는
것이 Wayland 세션에서 nixpkgs 가 의도한 설정이다. Brave 는 hosts/nixos/galaxy-chromebook-1/home.nix 에서 같은 플래그를
손으로 든다(brave-flags.conf 는 중복이지만 무해하고 터치 UI 플래그 때문에 남는다). 세션 변수라 바꾸면 로그아웃이 필요하다.

이 변수는 VS Code 터미널의 한글 누락과 무관하다
([postmortem](postmortems/2026-08-05-vscode-terminal-hangul.md)):

- 확인함: 플래그가 Chromium 에 닿는다(/proc/<pid>/cmdline; `code` 가 플래그마다 "not in the list of known options, but
  still passed to Electron/Chromium" 경고를 낸다 — 정상).
- 확인함: VS Code 한글 입력은 변수 전후 모두 된다.
- 안 해 봄: 어느 text-input 버전을 협상하는지, 누락에 영향이 있는지. 누락은 xterm.js 번들의 스케줄링 버그로 전부
  설명된다(고친 곳 overlays/vscode-xterm-hangul.nix — [overlays.md](overlays.md#vscode-xterm-hangul--패치가-안전한-이유와-깨질-때)).

## 폰트

공통 세트(D2Coding Nerd Font, Sarasa Gothic, Noto Sans CJK, Pretendard, 기본 Noto/이모지)는 `modules/shared/fonts.nix`
에 있다([fonts.md](fonts.md)). 여기는 리눅스 쪽만 원하는 것이다.

- OnlyOffice 는 fontconfig 을 안 써서 overlays/onlyoffice-fonts.nix 가 자기 목록을 든다
  ([overlays.md](overlays.md#onlyoffice-fonts--nixos-의-onlyoffice-가-폰트를-못-보는-것)).
- noto-fonts-cjk-serif-static: VF(가변 폰트) 판은 OnlyOffice 에서 Thin 으로 그려진다.
- d2coding(패치 안 된 "D2Coding")은 폴백이 찾는 패밀리 이름이다. Nerd 패치판은 "D2CodingLigature Nerd Font" 라 대신
  못 한다.
