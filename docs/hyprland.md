# Hyprland 세션

Hyprland 는 타일링 Wayland 컴포지터다. 이 저장소에서는 niri 옆의 두 번째 세션으로 깔고, DankMaterialShell(DMS,
Quickshell 기반 바·런처·알림 셸)이 그 위에서 돈다. 이 문서는 세션 모듈(`modules/nixos/hyprland/default.nix`)과
설정 파일(`modules/nixos/hyprland/rice/hyprland.lua`, 배치·체인 파일)의 전체 그림이다.

관련 문서:
- 키 배치의 정본은 [keymap.md](keymap.md), 하이프랜드에서 무엇을 부를 수 있는지는 [hyprland-binds.md](hyprland-binds.md).
- 화면 셰이더의 공통 규약(유니폼, 체인, 탭 곱, `!motion`)은 `modules/nixos/hyprland/rice/README.md`, 파일별 설계는
  [hyprland-shaders.md](hyprland-shaders.md).
- 라이싱 스튜디오 창은 [rice-studio.md](rice-studio.md), 스크립트는 [rice-scripts.md](rice-scripts.md)·[rice-tools.md](rice-tools.md).

## 왜 두 번째 타일링 컴포지터인가

niri 에는 출력 전체에 거는 셰이더 훅이 없다. 커스텀 셰이더는 창 열기·닫기·크기 바꾸기 애니메이션 안에만 있고, 계속
도는 셰이더는 상류에 아직 열린 요청이다(niri #913). Hyprland 에는 `decoration:screen_shader`(렌더링 끝에 적용되는
프래그먼트 셰이더)가 있어서 화면 전체 CRT 가 설정 한 줄이다. 화면 셰이더가 이 세션이 존재하는 이유다.

## 상류

전부 고정된 nixpkgs 에서 온다 — hyprland flake 입력은 없다. nixpkgs 가 0.56 을 싣고 있어 0.55 의 Lua 전환을 이미
넘었고, 상류 flake 는 hyprpm 플러그인이 버전이 맞는 컴포지터를 요구할 때에야 값어치가 생긴다.

## 세션

`programs.hyprland.enable` 은 그리터에 항목을 두 개 넣는다 — 패키지의 `passthru.providedSessions` 에
"Hyprland"(맨)와 "Hyprland (uwsm-managed)" 둘이 있다. uwsm 쪽을 쓴다(셸 배선이 거기 있다). 맨 항목은 uwsm 자체가
깨졌을 때의 대피로이고 거기서는 DMS 가 자동으로 안 뜬다. 기본 세션과 실제 로그인 대상은
[nixos-common](nixos-common.md#로그인-화면greetd과-세션)과 [subline](subline.md).

uwsm 은 Wayland 컴포지터를 systemd 유닛으로 감싸는 세션 관리자다: graphical-session.target 을 올리고, XDG autostart
를 돌리고, 세션을 로그인 세션에 묶고, 순서대로 내린다. Hyprland 자체의 systemd 지원은 niri 보다 얇다 — 0.56 은
hyprland-session.target 을 싣지 않고(위키는 손으로 쓰라고 한다) 상류는 uwsm 을 가리킨다. `withUWSM` 은
`programs.uwsm.enable` 만 켠다. 세션 항목은 hyprland 패키지가 직접 싣고, `programs.uwsm.waylandCompositors` 는 uwsm
desktop 항목이 없는 컴포지터용이다.

## DMS 를 이 세션에서도 띄우기 (`dms.wantedBy`)

nixpkgs 의 dms 모듈은 `wantedBy = [ cfg.systemd.target ]`(목록)을 쓰므로, 여기서 덧붙여도
`modules/nixos/niri` 의 `systemd.target = "niri.service"` 와 다투지 않는다. graphical-session.target 이 원하지 않으므로
GNOME 에는 안 뜬다. 인스턴스 이름은 컴포지터 desktop 항목 ID 다: 항목이 `uwsm start -e -D Hyprland hyprland.desktop`
을 돌리고 uwsm 은 그 인자로 유닛 이름을 짓는다. 확인: `systemctl --user list-units 'wayland-wm@*'`.

### 왜 wayland-session@….target 이 아니라 wayland-wm@….service 인가

target 에 걸면 DMS 가 영영 안 뜬다. 세션 로그:

```
wayland-session@hyprland.desktop.target: Found ordering cycle:
  dms.service/start after graphical-session.target/verify-active
  after wayland-session@hyprland.desktop.target/start - after dms.service
Job dms.service/start deleted to break ordering cycle
```

고리의 세 변:

1. target 은 자기가 Wants 하는 유닛에 암묵적으로 After 를 붙인다(systemd.target(5) — DefaultDependencies 가 no 가
   아니면 Wants/Requires 를 After 로 보강). 그래서 wantedBy 를 거는 순간 target 이 dms.service 뒤로 밀린다.
2. dms.service 는 After=graphical-session.target 을 들고 있다.
3. uwsm 의 wayland-session@.target 은 Before=graphical-session.target 이다.

systemd 는 고리를 끊으려고 dms.service 의 시작 작업을 지운다 → "에러도 없고 유닛은 enabled 인데 셸이 없는" 상태.
wayland-wm@….service 는 서비스라 1번 규칙이 없다. 그 서비스가 dms 를 끌어오고 dms 는 자기 After 대로
graphical-session.target 뒤에 뜬다(niri 모듈이 niri.service 에 거는 것과 같은 모양). 종료는 dms.service 의
PartOf=graphical-session.target 이 맡는다.

## 셰이더와 스튜디오

`rice/shaders` 에 네 갈래(crt / water / cyberpunk / print), `rice/chains` 에 체인이 있다. 고르고 겹치고 값을 맞추는
것은 라이싱 스튜디오(`rice/studio` QML, `apps/rice/studio` 가 띄움 — [rice-studio.md](rice-studio.md))다. DMS 에 남은
것은 여는 단추(DankBar 조각)와 탈출구 — Mod+Shift+C 순환, 런처(Mod+space 의 `:`)의 off 와 "다음 것". 셰이더가 화면을
못 알아보게 만들면 스튜디오 창도 같은 유리 뒤에 있기 때문이다.

셰이더는 `~/git/global-shader-for-macos` 에서 왔다. 그쪽은 맥에 없는 `decoration:screen_shader` 를 캡처+오버레이로
흉내 내는 프로그램이고, 규약을 하이프랜드에 맞춰 파일이 양쪽에서 그대로 돈다. 여기 것은 사본이라 한쪽에서 값을
고쳤으면 다른 쪽도 봐야 한다. `decoration:screen_shader` 는 경로만 받고 ~ 를 풀지 않아 전부 절대 경로다
(`apps/rice/crt`). 갈래 폴더 이름이 스위처·런처 이름의 앞부분이다(`crt/crt`).

체인을 한 파일로 접는 방식, 탭 곱, damage_tracking/vfr 두 축, glslang 검증은 `modules/nixos/hyprland/rice/README.md`
에 있다.

## 배치(레이아웃)

`general.layout` 과 그 레이아웃에서만 뜻이 있는 키바인드는 `rice/layouts/<이름>.lua` 가 한 벌씩 든다(scrolling 기본,
dwindle 둘째). hyprland.lua 는 `~/.config/rice/layout` 에 적힌 이름을 dofile 하고 `apps/rice/layout` 이 리로드 없이
갈아끼운다(옛 파일의 키를 풀고 새 파일을 돌린다 — [rice-tools.md](rice-tools.md#하이프랜드-배치--appsricelayout)).
스튜디오의 「배치」탭과 런처의 배치 축이 그 스크립트를 부른다. `~/.config/rice/layout` 은 심지 않는다 — 없으면 scrolling.

## 설치는 선언적, 라이싱은 아니다 (심기 규칙)

niri 와 같은 분리다([niri](niri.md#설치는-선언적-라이싱은-아니다)): 모듈은 세션을 설치·배선하고, 설정은 $HOME 의
쓰기 가능한 보통 파일로 `rice/` 에서 없을 때만 심는다(`[ -e ]` 가 모든 복사를 지킨다, 판정 규칙은
[rice-seeding](rice-seeding.md)). Hyprland 는 저장하면 hyprland.lua 를 핫 리로드하고 DMS 는 `~/.config/hypr/dms/` 에
조각을 쓴다 — 둘 다 store 심링크로는 안 된다.

- **셰이더는 갈래 폴더 하나씩 심는다.** 판정 단위가 곧 인자라, 통째로 넘기면 한 장만 값을 손봐도 폴더 전체가 "라이브가
  바뀜"이 되어 새 갈래가 영영 안 들어간다(증상: 런처에 셰이더가 crt 하나뿐). 갈래 단위면 손댄 갈래만 멈춘다. 목록은
  폴더에서 읽는다.
- **배치도 같은 이유로 파일 하나씩.** dwindle 을 손봤다고 scrolling 의 레포 변경까지 멈추면 안 된다.
- **체인**(`rice/chains`)은 한 줄에 한 칸, 위에서 아래로 겹친다. `apps/rice/crt --save <이름>` 이 쓰고 레포로 되받는
  것은 `apps/rice/save`.
- **스튜디오**(`~/.config/rice-studio`)는 폴더 통째로 심는다(`quickshell -p` 로 띄움). 파일끼리 참조해 반쪽만 들어가면
  깨지기 때문이다. 대가로 새 파일이 기존 머신에 안 들어가므로, QML 을 고쳤으면 `apps/rice/save` 로 되받는다.
  하이프랜드 밑에 두는 건 화면 셰이더가 이 세션에만 있어서이고, 창은 niri 에서도 뜨지만 값만 고친다(`apps/rice/crt` 의
  need_session).
- **장식(decor.lua)은 심지 않는다** — `apps/rice/decor` 가 처음 값을 바꿀 때 만드는 생성물이다. hyprland.lua 에 배선 한
  줄만 rice_ensure 로 넣는다. rice_sync 는 판정표 4행(양쪽 다 고침)에서 손을 떼므로, 그 줄이 없으면 "바꾼 값이 지금은
  먹는데 다시 로그인하면 원래대로" 가 된다. require 가 아니라 dofile 인 이유: require 된 파일은 감시되어 슬라이더마다
  (rice-decor 가 decor.lua 를 다시 씀) 전체 리로드되고, 리로드는 걸어 둔 화면 셰이더까지 지운다.
- **DMS 빈 조각**(`rice/dms`)은 DMS 가 처음 뜨기 전에도 hyprland.lua 의 require 가 찾게 한다(require 는 pcall 이라 없어도
  세션은 뜬다).
- **퇴역 셰이더**는 rice_sync 가 지우지 않아 $HOME 에 남고 스위처에 뜬다. crt.frag / crt-motion.frag 평면 두 장(crt/crt.frag
  이 대신)은 `<갈래>/<이름>` 으로 훑어 예외로 빠진다. cyberpunk/rain, print/riso, print/dither 는 레포에서 뺐다. 손본 값이
  있을 수 있어 알리기만 한다 — $HOME 의 라이싱 파일을 지우는 건 rebuild 의 일이 아니다.
- 터미널·런처·GTK 는 `modules/nixos/niri` 와 `modules/shared/ghostty` 가 심는다(컴포지터를 안 가린다).
- **rice-studio .desktop**: DMS 앱 검색은 Name·GenericName·Keywords 를 본다(Services/AppSearchService.qml). 라이싱
  플러그인은 `:` 트리거 안에서만 답해서, 이 항목이 없으면 트리거를 모르는 손은 스튜디오를 못 찾는다. Exec 가 sh 를
  거치는 건 .desktop 의 Exec 가 환경 변수를 안 풀어서 $RICE_REPO 폴백을 셸에 맡기려는 것이고, 따옴표·$ 는 desktop
  규격대로 \ 로 가린다(makeDesktopItem 이 desktop-file-validate 를 돌린다).
- **hyprshot**: hyprctl 로 활성 창 영역을 묻는 스크린샷 도구. 맨 `grim -g "$(slurp)"` 로는 안 되는 모드다. 니리는 스스로 찍는다.

## hyprland.lua — 설정 파일의 규칙

### 파일의 성격

손으로 고치는 파일이다. 살아있는 사본은 `~/.config/hypr/hyprland.lua` 이고, 저장하면 하이프랜드가 바로 리로드하며
문법이 깨진 편집은 에러만 찍고 직전 설정이 계속 돈다. 레포 쪽은 시드 겸 백업(모듈이 없을 때만 복사). 0.55 부터
hyprlang 은 deprecated 이고 설정은 Lua 다 — 인터넷의 hyprland.conf 예제는 `hyprconf2lua` 로 변환하거나 Lua 문법으로
쓴다(값 이름은 같아 위키 변수표는 유효). 키 배치는 `modules/nixos/niri/rice/config.kdl` 에서 옮겼다(근육기억이 갈리는
게 제일 큰 비용). 1:1 은 아니다.

### 입력

- **클릭 포커스**(follow_mouse = 0), 세 WM 공통(니리는 focus-follows-mouse 줄이 없고 rift-grid 는
  focus_follows_mouse = false). 호버 포커스와 키보드 타일러는 주도권에 대한 답이 다르다 — 포인터는 마지막 자리에 남아
  포커스를 계속 주장해서, 키보드로 옮긴 창에 타이핑하면 첫 타가 커서 밑 엉뚱한 창으로 가고 배경 창 위에서 스크롤하면
  포커스를 뺏긴다. 반대 방향(키보드 포커스에 커서가 따라옴)은 rift-grid 에서만 켰다(하이프랜드엔 같은 설정이 없다).
- **휠 클릭 스크롤**(libinput on-button-down): 누른 채 움직이면 스크롤, 움직이지 않고 떼면 휠 클릭이 뗀 순간에 나간다
  (libinput 이 릴리즈까지 유보). 대가로 미들 드래그(패닝)는 사라진다. 장치별로 거는 이유: input.scroll_method 는
  터치패드에도 걸리는데 input.touchpad 에는 되돌릴 scroll_method 가 없다(0.56 스텁 HL.ConfigOpt.Input.Touchpad) —
  노트북에서 두 손가락 스크롤이 조용히 죽는다. 마우스를 바꾸면 이름도 바꾼다(`hyprctl devices` 의 mice 절).
  scroll_button_lock 은 클릭 한 번이 스크롤 모드 토글이 되어 휠 클릭이 없어지므로 켜지 않는다.
- **세 손가락 가로 스와이프는 트랙패드 전용.** 0.56 제스처 엔진은 통째로 트랙패드 것이고(바이너리 심볼이 전부
  `C*TrackpadGesture`), 터치스크린은 구형 `gestures.workspace_swipe_touch` 로만 넘긴다(0.56 기준 유일).
- **터치스크린·스타일러스는 eDP-1 에 못 박는다.** 없으면 외장 모니터를 붙이는 순간 터치 좌표가 내장+외장 전체 넓이에
  매핑되어 가로로 늘어난 엉뚱한 자리가 눌린다(모니터 하나일 때는 증상 없음). 0.56 에는 태블릿 transform 이 있다
  (`hyprctl getoption input:tablet:transform`).
- **태블릿 모드**: 360도로 접으면 EC 가 SW_TABLET_MODE 를 세우고 하이프랜드는 스위치 장치로 본다(`hyprctl devices` 의
  Switches 절 "Tablet Mode Switch"). 이름이 곧 바인드 키라 다른 섀시에서는 조용히 안 걸린다. `tablet-mode` 는 갤럭시
  크롬북의 touch.nix 가 깔고 키보드 억제·터치패드·자동 회전·화면 키보드를 같이 움직인다(libinput 에 안 맡기는 이유는
  [galaxy-chromebook-1](galaxy-chromebook-1.md#태블릿-모드에서-키보드를-우리가-끄는-이유)). locked = true: 잠긴 채 접는
  것이 흔하고 그때 자판이 등 뒤에서 눌리는 것이 제일 곤란하다.
- **화면 키보드 Mod+B**(`osk toggle`)는 노트북 자세용. 접으면 누를 수 없어 태블릿 모드 스위치가 맡는다. B 는 Board.

### 모양

- **misc.focus_on_activate = true**: 단일 인스턴스 앱(OnlyOffice 등)은 두 번째 실행이 기존 인스턴스에 넘기고 죽는다. 그
  인스턴스의 활성화 요청(xdg-activation, X11 은 _NET_ACTIVE_WINDOW)을 false 면 버려서 "켰는데 아무 일도 없음"이 된다.
  스크롤링 레이아웃에서는 창이 띠 위 화면 밖에 살아 있어 증거조차 없고, XWayland 창은 스스로 포커스를 못 가져와 더
  그렇다. 대가는 앱이 아무 때나 포커스를 뺏는 것 — 거슬리면 그 창만 windowrule 로 좁힌다.
- **환경 변수(hl.env)는 하이프랜드의 자식에만 간다.** DMS 는 uwsm 유닛으로 떠서 못 본다. 셸까지 닿을 변수는
  `~/.config/uwsm/env` 나 environment.sessionVariables.

### 키바인드

- **DMS 의 기본 묶음(dms/binds.lua)은 안 읽는다.** 하이프랜드는 같은 키의 바인드를 위에서부터 전부 실행해서(니리처럼
  덮지 않음) 겹치는 키(Mod+F, Mod+Q…)가 토글을 두 번 때린다. 셸의 치트시트(Mod+H)는 이 파일을 읽어 만든다.
- **티어**: Mod(간다·연다), Mod+SHIFT(창을 데리고 간다), Mod+CTRL(모니터를 넘는다·WM 에게 말한다). macOS 만 mod 가
  Alt(Cmd 는 시스템이 가져감). 라이싱 스크립트 묶음은 티어 규칙 밖(리눅스 전용, 어느 티어와도 안 부딪힘). 표와 버린
  키는 [keymap.md](keymap.md).
- **이웃과 합치기/떼기(Mod+Ctrl+E)** 는 하이프랜드에 한 액션이 없고 "이웃"이 레이아웃마다 다르다(스크롤링은 컬럼
  consume/promote, dwindle 은 그룹). 그래서 배치 파일이 갖는다.
- 마우스 드래그/리사이즈(mouse:272/273)는 니리엔 없지만 하이프랜드 관용.
- **스크린샷**: hyprshot. 저장 위치는 니리의 screenshot-path 와 같다. `-m window` 만 주면 창을 고르라고 기다리므로 지금
  창을 찍으려 `-m active` 를 덧붙인다.
- **미디어 키**: locked=true 는 잠금 화면에서도(니리의 allow-when-locked), repeating=true 는 누르고 있으면 반복.
- **밝기** `increment(step, device)`: 오디오(`increment(step)`)를 보고 하나만 넘기면 DMS 가 "Too few arguments provided"
  로 조용히 거절한다. 빈 문자열은 기본 장치(evo-t1 에서는 ddc:i2c-10 = 40LGD5K).
- **라이싱 스크립트 경로**는 `${RICE_REPO:-$HOME/nixos-config}`(exec_cmd 는 sh -c 를 거친다). 빗나가면 키가 조용히
  아무 일도 안 한다 — 하이프랜드는 exec 실패를 안 알려서 `apps/doctor` 가 체크아웃 위치를 짚는다. 프로필 전환은 두
  세션이 반씩이다 — 니리 조각(profile.kdl)은 여기서 무의미하고 DMS 조각(색·투명도·둥글기)은 적용된다.
- **Mod+SHIFT+R**: RiceSwitcher 트리거(":")를 친 채 런처를 연다. 프로필·터미널·월페이퍼가 한 목록, 걸린 것에 ✓, 값은
  `apps/rice/menu`. 화면 셰이더는 값이 없고 스튜디오를 여는 줄과 탈출구(off · 다음 것)만.

### 배치를 파일로 가르는 이유

레이아웃은 값 하나(general.layout)가 아니다. 컬럼 사이 이동·폭·합치기 키는 레이아웃마다 다른 디스패처라, 값만 바꾸면
그 키들이 `Unknown layoutmsg` 로 조용히 죽는다. 둘을 한 파일에 묶으면 어긋날 자리가 없다. dofile 로 읽은 파일은 감시
목록에 안 들어가고 라이브 반영은 `apps/rice/layout` 이 eval 로 한다. 손으로 고쳤으면 `apps/rice/layout --reload`. 읽기에
실패하면 scrolling 으로 떨어진다 — pcall 로 삼키고 끝내면 컬럼 키가 다 죽은 세션이 소리 없이 뜬다.

### 화면 셰이더

순환 목록은 `apps/rice/crt --next` 가 쥔다. 체인은 하이프랜드에 걸 파일을 만들어 내야 해서(`apps/rice/chain`) lua 설정
안에서 할 일이 아니고, 순환 목록을 두 곳에 두면 안 고친 쪽이 조용히 낡는다. 이 파일에 남은 것은 "무엇으로 시작할까"
하나다.

**두 축** ([postmortem](postmortems/2026-08-04-hyprland-crt.md)):

- `debug:damage_tracking` — 어디를 그리는가. 기준은 `time` 이 아니라 셰이더가 자기 픽셀 밖을 읽는가다. CRT 들은 전부
  읽는다: curve() 는 배럴 왜곡으로 가장자리에서 수십 px, gun() 은 색수차로 ±3 px, bloom() 은 5 px 반경 16 탭. 바뀐
  사각형만 다시 합성하면 바깥 이웃이 낡아 움직이는 것 둘레에 잔상이 남고, stripes() 의 fwidth() 는 사각형 경계에서
  불연속이라 스캔라인 세기가 사각형 모양으로 갈린다. 그래서 셰이더가 걸리면 무조건 0.
- `debug:vfr` — 그릴지 말지. VFR 이면 데미지가 없을 때 프레임을 안 그려 time 을 쓰는 셰이더가 멈춘다(마우스를 움직여야
  험 바가 한 칸). 정지 셰이더는 화면이 바뀔 때만 그리면 충분하다(실측: damage 0 + vfr 켬으로 잔상 없음). 끄면 정지
  화면을 주사율대로 다시 그리는 낭비다. 판정은 `time` 유무가 아니라 흐르는 것을 여는 손잡이가 0 이 아닌지다 —
  crt.frag 은 그레인·험 바·클릭 파문을 0 으로 내리면 정지 셰이더다. 그 손잡이는 셰이더가 `!motion` 으로 선언한다
  (`apps/rice/chain --motion`). 배터리 비용은 vfr 쪽에 붙어 있다.

**리로드마다 다시 돈다.** 하이프랜드는 이 파일과 require 된 조각이 바뀔 때마다 설정을 다시 읽고, 그때 screen_shader 는
비워진다 — 리로드 평가 시점에는 hl.get_config 도 빈 값을 준다(실측 2026-08-12). DMS 는 테마·간격이 바뀔 때마다 dms/
조각을 다시 써서 프로필 전환마다 리로드가 일어난다. 이름 하나를 그대로 걸면 골라 둔 셰이더가 매번 되돌아간다. 그래서
`--boot`: 마지막으로 건 것(`~/.config/rice/shader`, rice-crt 가 걸 때마다 적음)을 도로 걸고, 없을 때만 crt_start. off
로 꺼 뒀으면 off. 한 번이라도 스위처로 골랐으면 그쪽이 이긴다(crt_start 를 고칠 게 아니라 `apps/rice/crt` 로 건다).
crt_start 는 갈래/이름, 체인 이름("chain/bad-signal"), "off" 가 된다.

`hl.exec_cmd` 와 `hl.dsp.exec_cmd` 는 다르다: dsp 쪽은 디스패처를 만들어 돌려주고(hl.bind 인자용), 이쪽은 그 자리에서
실행하고 nil 을 돌려준다(share/hypr/stubs/hl.meta.lua). dsp 쪽을 쓰면 증상은 "로그인하면 셰이더가 안 걸린다".

다음 것은 컴포지터에 걸린 것에서 고른다 — 카운터를 두면 밖에서(런처) 바꾼 순간 어긋난다.

밖에서 다루기: `hyprctl keyword` 는 lua 설정에서 거절된다("keyword can't work with non-legacy parsers. Use eval.").

```
apps/rice/crt off | crt/crt | water/still | chain/bad-signal | --next | --reload
apps/rice/crt water/still print/paper     # 즉석 체인
hyprctl eval 'hl.config({decoration={screen_shader=""}})'
```

### DMS 조각

셸이 설정 GUI 와 matugen(벽지에서 팔레트를 뽑는 도구)으로 쓰는 파일(색·커서·모니터·창 규칙). 마지막에 불러 겹치는
값(gaps, rounding)은 DMS 가 이긴다 — 레포 값으로 되돌리려면 그 줄을 뺀다. pcall 은 니리 include 의 `optional=true` 와
같은 뜻이다(파일 하나가 없다고 세션이 하이프랜드 기본값으로 떨어지면 안 된다). binds-user 는 DMS 설정 GUI 가 키를
추가하는 자리(기본 빈 파일)이고, 위에서 잡은 키를 또 잡으면 둘 다 실행되니 그 파일에서 hl.unbind() 를 먼저 부른다(키
문자열은 대소문자까지 같게).

이름을 리터럴로 적는 이유: DMS 커서 테마 설정(Modules/Settings/ThemeColorsTab.qml)이 `grepPattern: "dms.cursor"`,
`includeLine: require("dms.cursor")` 로 문자열 검색해 못 찾으면 파일 끝에 덧붙인다. 런타임에 조립하면
(`"dms." .. fragment`) 중복 require 줄이 붙고 apps/rice/save 로 레포까지 간다. 니리 쪽은 `include "dms/cursor.kdl"` 이
그대로 적혀 있어 같은 일이 없다.

dms/colors.lua 는 matugen 이 테마 변경마다 통째로 다시 쓴다(보더, 그룹바 색). 색을 직접 잡으려면 require 목록에서
"colors" 를 빼고 general.col 을 적는다.

### 장식 조각

투명도·흐리게·어둡게·그림자. `apps/rice/decor` 가 쓰는 생성물이고 스튜디오 "장식" 탭이 부른다
([rice-tools.md](rice-tools.md#장식-값--appsricedecor)). DMS 조각 뒤라 겹치면 이쪽이 이긴다. 지금은 안 겹치지만(DMS 는
gaps·rounding·border_size, 이쪽은 opacity·blur·shadow) 잘못된 방향이라 rice-decor 의 표에서 DMS 키를 뺐다 — 순서가
아니라 표가 안전장치다. dofile 로 읽은 파일은 감시 목록에 안 들어간다(실측 2026-08-12, 설정 디렉터리 안이어도). 라이브
반영은 rice-decor 의 eval 이 하고 이 줄은 다음 세션·리로드용이다. 아무 값도 안 바꾼 머신에는 파일이 없다.

## 배치 파일과 체인

`rice/layouts/scrolling.lua`, `rice/layouts/dwindle.lua`, `rice/chains/*.chain`.

### 레이아웃 파일의 계약

- 레이아웃 파일이 소유하는 것: general.layout, 그 레이아웃의 값 블록, 레이아웃마다 뜻이 달라지는 키. 방향·워크스페이스·
  모니터 티어는 hyprland.lua. 어느 파일을 읽을지는 `~/.config/rice/layout`(없으면 scrolling), 갈아끼우는 것은
  `apps/rice/layout`(리로드 없이 옛 키를 풀고 다시 돌림). 그래서 레이아웃 파일은 몇 번 다시 돌려도 같은 결과여야 한다
  (상태를 쌓지 말고 선언만).
- `-- @0.2..0.9:0.05 설명` 이 붙은 값만 스튜디오 「배치」탭의 손잡이가 된다(apps/rice/layout 이 읽고 씀; 셰이더의
  `// @범위` 와 같은 규약). 설명은 바로 위 주석 덩어리와 범위 뒤 글자, 구역은 `-- ── 이름 ──` 줄, 파일 첫 주석 덩어리
  (첫 줄 ` — ` 앞이 제목)가 목록 설명이다. 문자열 값에는 못 단다.

### scrolling

니리와 같은 무한 띠다(컬럼이 오른쪽으로 쌓이고 창이 화면 밖에 살 수 있다). 값은 니리 config.kdl 의 layout 블록에서
옮겼다.

- **포커스 보정.** layout("focus …") 는 키보드 포커스만 옮긴다(ScrollingAlgorithm::focusTargetUpdate 는 fullWindowFocus
  하나). hl.dsp.focus 가 거치는 switchToWindow 와 달리 simulateMouseMovement 가 없고, 공백을 메울
  sendMotionEventsToFocused 는 커서 밑 표면이 서브서피스면 "바나 팝업"으로 보고 돌아가는데 VS Code·Chrome 계열은 창
  전체를 서브서피스로 그린다. 그래서 Mod+J/L 뒤 마우스를 안 움직이고 클릭하면 버튼이 옛 창으로 가고, 그 창이
  xdg-activation 으로 포커스를 가져간다(misc.focus_on_activate). cursor.move 로 커서를 제자리에 다시 놓으면 워프 뒤
  simulateMouseMovement 가 돌아 포인터 포커스를 다시 잡는다(커서는 눈에 띄게 안 움직인다).
  [postmortem](postmortems/2026-10-13-hyprland-click-after-keyboard-focus.md).
- **focus-column-first/last 가 없는 이유.** focus 의 `window` 는 위치 키워드가 아니라 창 셀렉터(class:, title:,
  address:)라 "first"/"last" 는 경고만 찍는다. layoutmsg("focus ...") 는 첫 글자만 방향으로 읽어
  leftmost/rightmost/last 가 한 칸만 가고 끝에서 감싸 돈다. 되살리려면 hl.get_windows() 로 컬럼을 훑는 함수를 쓴다
  ([hyprland-binds.md](hyprland-binds.md)).
- **Mod+C**(fit_into_view)는 니리 center-column 과 다르다 — 활성 컬럼을 화면 안에 넣기만 하고 가운데 정렬은
  focus_fit_method 가 정한다. **Mod+R**(colresize +conf)은 니리 switch-preset-column-width. rift-grid 에는 이 동작이 없어
  같은 키에 monocle 스크립트가 걸린다.
- **Mod+Ctrl+E 합치기/떼기**(rift-grid 의 consume_or_expel_window, 니리의 consume-or-expel-window-right 자리). 하이프랜드
  에는 한 액션이 없어 상태를 보고 고른다: consume(다음 컬럼 맨 위 창을 끌어옴), promote(활성 창을 빼서 오른쪽 새
  컬럼으로). expel 은 포커스와 무관하게 맨 아래 창을 뱉으므로(니리 문서도 expel-window-from-column 을 "the bottom
  window" 라 적는다) 쓰지 않는다 — 좌표를 재서 확인했다(hyprland-binds.md 의 layoutmsg 표). 컬럼 판별은 x 좌표(같은
  컬럼은 정확히 같음), 띄운 창은 뺀다. promote 로 나간 창은 맨 오른쪽이라 다시 누르면 `no next column` 이다 —
  되돌리려면 왼쪽 컬럼에서 누른다.

### dwindle

화면을 이진 분할하는 BSP 레이아웃이고, 창은 늘 화면 안에 있다. 같은 키 자리를 다른 뜻으로 쓴다.

- J/L 은 트리 이웃(감싸 돌지 않고, 옆 모니터로 안 샌다).
- 폭 자리는 창 크기 조절(가로 40px 상대, 분할 비율이 따라 움직여 이웃도 변한다). 인자 모양
  `{ x, y, relative?, window? }` 는 바이너리의 에러 문구에서 확인했다.
- 합치기 자리는 그룹(탭으로 묶인 창). 소유 키 집합이 scrolling 과 같지 않아도 된다. 니리에서 옮겨올 값은 없다(분할
  트리가 없다).
- layoutmsg(이름은 바이너리에서 확인: togglesplit swapsplit preselect movetoroot): togglesplit(분할 방향 뒤집기,
  preserve_split 이 꺼져 있으면 다음 창에 되돌아감), swapsplit(두 쪽 맞바꿈), movetoroot(뿌리로 올려 절반 차지).
  pseudo 는 window 디스패처로, 타일 자리는 두고 제 크기로 그린다(다이얼로그용). 키는 T=Tree, R=Root, P=Pseudo.
- Mod+C 는 없다(창이 화면 밖으로 안 나간다).
- Shift+J/L 은 window.move — 트리에 옮겨 심으므로 모양이 매번 같지 않다. 자리만 바꾸려면
  `hl.dsp.window.swap({ direction = "l" })`.
- 그룹: 다른 창은 탭바로 끌어다 놓는다(group:drag_into_group 기본값). 키로는
  `hl.dsp.window.move({ into_group = "l"/"r"/"u"/"d" })`(아직 안 걸었다). 탭 사이는 Mod+[ / ]. 그룹 안에서도 Mod+I/K 는
  그룹 밖 이웃으로 간다.

### 체인 bad-signal

glitch → paper, 15탭. glitch 가 주사선을 어긋내고 색을 분리하면 paper 가 종이 결과 잉크 번짐을 얹는다. 디지털 고장과
아날로그 인쇄가 어울릴 이유가 없어 보이지만, 글리치가 "인쇄 사고"처럼 읽혀 한 덩어리가 된다. paper 가 5탭이라 한 장 더
얹으려면 한 탭짜리여야 한다(지금은 term/glow 뿐).
