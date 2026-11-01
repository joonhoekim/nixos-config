# 한국어 입력 (NixOS)

`modules/nixos/korean.nix` 는 NixOS 쪽 로케일, 한글 입력기, 리눅스 전용 폰트를 맡는다. 입력기는 fcitx5(리눅스의 입력기
프레임워크)와 그 hangul 엔진이고, 한/영 키는 keyd(커널 아래에서 키를 리맵하는 데몬)가 만든다. 공통 폰트는
[fonts.md](fonts.md).

## 로케일

UI 는 en_US, 지역 포맷은 ko_KR. LC_TIME 만 en_DK.UTF-8 이다. ko_KR 이면 날짜를 그리는 모든 것이 한국어가 된다 —
`date` 가 "2026. 08. 01. (토)", DMS 바 시계가 영어 라벨 옆에 토 / 오후(Qt 는 요일 이름과 12/24시간 선택을 이 범주에서
가져간다). en_DK 는 영어 로케일(Sat, August)이면서 LC_TIME 이 ISO 8601 이다 — d_fmt "%Y-%m-%d", t_fmt "%T", am_pm 비어
있음. i18n.supportedLocales 는 defaultLocale 과 이 값들의 합집합이 기본이다.

## 한/영 키가 지나는 길

Right Alt → Hangul 리맵은 `modules/nixos/keyboard.nix` 의 keyd 가 한다(머신당 설정 하나, 같은 설정이 Caps 레이어도
건다 — [keymap.md](keymap.md)). 세 키코드 이름공간을 건너며 이름이 매번 다르다:

```
keyd `rightalt = hangeul`  ->  evdev KEY_HANGEUL (122)
  -> xkb <HNGL>, keycode 130 (evdev + 8)
  -> keysym `Hangul`, symbols/pc 의 유일한 섹션 pc105 에 있어 맨 `us` 를 포함한 모든 레이아웃이 가진다
  -> fcitx5 Hotkey/TriggerKeys -> keyboard-us <-> hangul 토글
```

확인: 첫 홉은 *keyd virtual keyboard* 장치에 `sudo evtest`, 마지막은 fcitx5 키 로그다.

```
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.SetLogRule "keytrace=5"
journalctl --user -fu 'app-org.fcitx.Fcitx5@autostart.service'
```

닿으면 `KeyEvent: Key(Hangul ...) keycode: 130`. 끄려면 SetLogRule 에 ""(매우 시끄럽다).

## NIXOS_OZONE_WL

nixpkgs 는 Electron/Chromium 의 Wayland IME 플래그를 이 세션 변수 뒤에 둔다:
`${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}`.
변수가 없으면 VS Code 는 네이티브 Wayland 창(hyprctl clients: xwayland false)인데 이 플래그는 하나도 없다. 변수를 켜는
것이 Wayland 세션에서 nixpkgs 가 의도한 설정이다. Brave 는 hosts/nixos/galaxy-chromebook-1/home.nix 에서 같은 플래그를
손으로 든다(brave-flags.conf 는 중복이지만 무해하고 터치 UI 플래그 때문에 남는다). 세션 변수라 바꾸면 로그아웃이 필요하다.

이 변수는 VS Code 터미널의 한글 누락과 무관하다
([postmortem](postmortems/2026-08-05-vscode-terminal-hangul.md)):

- 확인함: 플래그가 Chromium 에 닿는다(/proc/<pid>/cmdline; `code` 가 플래그마다 "not in the list of known options, but
  still passed to Electron/Chromium" 경고를 낸다 — 정상).
- 확인함: VS Code 한글 입력은 변수 전후 모두 된다.
- 안 해 봄: 어느 text-input 버전을 협상하는지, 누락에 영향이 있는지. 누락은 xterm.js 번들의 스케줄링 버그로 전부
  설명된다(고친 곳 overlays/vscode-xterm-hangul.nix — [overlays.md](overlays.md#vscode-xterm-hangul--패치가-안전한-이유와-깨질-때)).

하이프랜드는 text-input v1 과 v3 를 둘 다 준다: `wayland-info | grep text_input` → `zwp_text_input_manager_v1`
(version 1, name 20), `zwp_text_input_manager_v3`(version 1, name 21).

## fcitx5 프로필은 시드다

fcitx5 는 ~/.config/fcitx5/* 를 /etc/xdg/fcitx5/* 보다 먼저 읽고 시작할 때 profile 을 직접 쓴다. 사용자 사본이 있는
머신은 rebuild 뒤 ~/.config/fcitx5/{profile,config} 를 한 번 지워야 선언이 먹는다. ignoreUserConfig 로 무조건 먹게 할
수 있지만 fcitx5 가 아무것도(설정 GUI 것 포함) 저장 못 하게 되어 안 쓴다.

- DefaultIM 은 토글이 켜는 IM 이지 시작 상태가 아니다 — ActiveByDefault 가 false 라 입력란은 Items/0(영어)로 열린다.
- 애드온: fcitx5-gtk(GTK3/4 IM 모듈), qt6Packages.fcitx5-qt(Qt6), fcitx5-configtool(GUI).
- Items/1 hangul 의 Layout = "us" 는 한글 IM 에서도 US 물리 배열이라는 뜻이다.

## 그룹은 정확히 둘

그룹에 keyboard-kr 을 셋째로 넣지 않는다. keyboard-kr 은 엔진이 아니라 xkb 레이아웃이고 `kr` 은 키 몇 개가 더 있는 US
QWERTY 라 라틴을 똑같이 친다(한글은 hangul 엔진에서). 트리거 키에 첫째와 똑같아 보이는 셋째 상태만 생긴다(아래
EnumerateWithTriggerKeys 와 겹치면 한/영이 반쯤 고장 난 것처럼 군다).

## EnumerateWithTriggerKeys

/etc/xdg/fcitx5/config 로 쓰인다(이 파일이 없으면 모든 핫키가 컴파일된 기본값). Instance::trigger()
(src/lib/fcitx/instance.cpp):

```
if (!enumerateWithTriggerKeys() || (firstTrigger_ && isActive()) ||
    (enumerateSkipFirst() && inputMethodList().size() <= 2))
  toggle(ic);
else
  enumerate(ic, true);
```

기본값(true)이면 enumerate() 로 빠져 그룹을 순환한다. 세 항목 그룹이면 keyboard-us → hangul → keyboard-kr 이고 둘이
라틴이다. false 면 무조건 toggle().

**값은 문자열 "False" 다.** nixpkgs 모듈이 맨 `lib.generators.toINI {}` 로 렌더해 Nix bool 을 `false` 로 쓰는데 fcitx5
는 "True"/"False" 만(대소문자 구분) 받고 그 밖은 컴파일된 기본값으로 떨어진다(unmarshallOption(bool),
src/lib/fcitx-config/marshallfunction.cpp). bool 로 쓰면 "맞는 설정인데 아무 일도 안 함"이 된다. hangul 애드온 블록의
따옴표도 같은 이유다.

**TriggerKeys 를 고정한다** — 상류 기본값 변경이 한/영을 조용히 가져가지 않게. Hangul 은 keyd 가 Right Alt 로 내는
keysym, Control+space 는 Hangul 경로 자체를 디버깅할 때의 탈출구다(화면 키보드에서도 이걸 쓴다). 기본 목록의
Zenkaku_Hankaku 는 이 머신에서 아무것도 안 내서 뺐다.

## 폰트

공통 세트(D2Coding Nerd Font, Sarasa Gothic, Noto Sans CJK, Pretendard, 기본 Noto/이모지)는 `modules/shared/fonts.nix`
에 있다([fonts.md](fonts.md)). 여기는 리눅스 쪽만 원하는 것이다.

- OnlyOffice 는 fontconfig 을 안 써서 overlays/onlyoffice-fonts.nix 가 자기 목록을 든다
  ([overlays.md](overlays.md#onlyoffice-fonts--nixos-의-onlyoffice-가-폰트를-못-보는-것)).
- noto-fonts-cjk-serif-static: VF(가변 폰트) 판은 OnlyOffice 에서 Thin 으로 그려진다.
- d2coding(패치 안 된 "D2Coding")은 폴백이 찾는 패밀리 이름이다. Nerd 패치판은 "D2CodingLigature Nerd Font" 라 대신
  못 한다.
