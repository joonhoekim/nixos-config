# TODO — 키보드로 포커스를 옮긴 직후의 클릭이 이전 창으로 포커스를 되돌린다

하이프랜드 0.56.2 · `input:follow_mouse = 0` · `misc:focus_on_activate = true`
(`modules/nixos/hyprland/rice/hyprland.lua`). 2026-10-08 기준 **원인 미확정, 가려내는
실험까지 준비된 상태**다. 아래 「가려내기」를 돌려서 결과를 이 문서에 적고 고친다.

## 증상

1. `Mod+J/L` 같은 키로 창 A 에서 창 B 로 포커스를 옮긴다.
2. **마우스를 전혀 움직이지 않고** 클릭한다.
3. 포커스가 A 로 되돌아간다.

마우스를 조금이라도 움직인 뒤에 클릭하면 안 일어난다. 이 조건이 결정적이다 —
"가끔" 으로 보이던 것은 클릭 전에 손이 움직였느냐의 차이였다.

## 확인한 사실 (소스와 라이브)

- **키보드 포커스 이동은 커서를 새 창 가운데로 워프한다.**
  `config/shared/actions/ConfigActions.cpp` 의 `switchToWindow()` 가
  `fullWindowFocus(B)` → `B->warpCursor()` → `simulateMouseMovement()` 순으로 돈다.
  `cursor:no_warps` 가 false 라 실제로 뛴다 — 이 세션에서
  `hyprctl dispatch 'hl.dsp.focus({direction="l"})'` 를 날리자 `hyprctl cursorpos` 가
  (1865,1180) → (540,984) 로 바뀌었다.
- 그러므로 "안 움직이고 클릭" 은 **B 의 한가운데를 클릭하는 것**이다.
- **그 클릭에서 하이프랜드 자신은 포커스를 안 바꾼다.** 버튼 핸들러
  (`managers/input/InputManager.cpp` 의 `processMouseDownNormal`)는 커서 밑 창을
  히트 테스트해서 포커스 창과 **다를 때만** `refocus()` 한다. B 가운데의 히트
  테스트는 B 고 포커스도 B 라 아무 일도 안 한다.
- 버튼 이벤트는 히트 테스트 결과가 아니라 **포인터 포커스 표면**
  (`g_pSeatManager->m_state.pointerFocus`, 마지막으로 `wl_pointer.enter` 를 보낸
  표면)으로 배달된다(`sendPointerButton`).
- xdg-activation 요청은 `CWindow::activate()` 로 들어오고, 거기서 `urgent` IPC
  이벤트를 낸 뒤 `focus_on_activate` 가 참이면 그 창을 포커스하고 **커서까지 그
  창으로 워프**한다(`desktop/view/Window.cpp`).
- `cursor:warp_back_after_non_mouse_input` 은 false 다(그게 켜져 있으면 같은 증상이
  더 단순한 이유로 난다). `cursor:hide_on_key_press` 도 false.
- 같은 증상군이 상류에 열려 있다: hyprwm/Hyprland Discussion #12192
  "포커스가 바뀐 뒤 커서를 움직이기 전까지 입력이 옛 창으로 간다". 메인테이너
  답은 "범용 수정은 아직 없다".

## 남은 가설 (하나)

키보드 포커스가 B 로 간 뒤에도 **포인터 포커스 표면이 A 로 남아 있다.** 그러면:

1. 클릭이 A 에게 배달된다.
2. 포커스 없는 창이 클릭을 받으면 Chromium 계열(Brave·Chrome·VS Code)은
   xdg-activation 으로 활성화를 요청한다.
3. `focus_on_activate = true` 라 하이프랜드가 A 를 포커스하고 커서도 A 로 되돌린다.
4. 마우스를 움직이면 진짜 motion 이벤트가 `mouseMoveUnified` 를 거쳐 포인터
   포커스를 B 로 갱신하므로 증상이 사라진다.

왜 포인터 포커스가 낡은 채 남는지는 소스만으로 못 박지 못했다. 코드상으로는
`rawWindowFocus` 끝의 `sendMotionEventsToFocused()`(follow_mouse 0 전용)와
`switchToWindow` 의 `simulateMouseMovement()` 둘 다 B 로 갱신해야 한다. 의심 지점
하나: `simulateMouseMovement()` 는 motion 을 보내고 **`wl_pointer.frame` 을 안 보낸다**
(`onMouseMoved` 는 보낸다). libwayland 클라이언트는 frame 까지 이벤트를 묶어 두므로
B 쪽에서는 그 enter/motion 이 다음 실제 이벤트까지 반영 안 될 수 있다. 추정이다.

## 가려내기 (30초)

활성화 경로는 포커스를 바꾸기 **직전에 `urgent` 이벤트**를 낸다. 하이프랜드의 자체
refocus 는 안 낸다.

```sh
socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - \
  | grep --line-buffered -E '^(urgent|activewindowv2)>>'
```

재현했을 때:

| 보이는 것 | 뜻 | 할 일 |
|---|---|---|
| `urgent>>A` 바로 뒤 `activewindowv2>>A`, 커서도 A 로 되돌아감 | 위 가설 그대로 | 아래 「조치」 |
| `urgent` 없이 `activewindowv2>>A` 만 | 하이프랜드가 직접 되돌린 것 — 가설 틀림 | 디버그 로그로 재조사 (`hl.config({debug={disable_logs=false}})`, `Set keyboard focus to surface` 줄의 순서) |

## 조치 후보

가설이 맞을 때, 둘 중 하나.

- **`focus_on_activate` 를 전역에서 끄고 필요한 앱에만 윈도룰로 준다.** 가장 확실하다.
  전역을 켠 이유는 OnlyOffice 같은 단일 인스턴스 앱의 두 번째 실행이 "켰는데 아무
  일도 안 일어남" 이 되기 때문이라(`hyprland.lua` 의 misc 주석), 그 앱 클래스에만
  `hl.window_rule({ match = {class=…}, focus_on_activate = true })` 로 좁힌다.
- **포커스 키에서 포인터 포커스를 밀어 준다.** `hl.dsp.focus` 를 Lua 함수로 감싸
  뒤에 `hl.dsp.cursor.move` 로 지금 자리에 한 번 더 워프한다. `Actions::moveCursor` 는
  `warpTo(force) + simulateMouseMovement()` 라 frame 문제가 원인이면 **안 먹을 수
  있다** — 실측 필요. 먹으면 `layouts/*.lua` 의 J/L 과 `hyprland.lua` 의 I/K 양쪽에
  같은 포장이 들어간다.

상류에 올릴 가치가 있다. #12192 에 "키보드 movefocus + 워프 + 무이동 클릭" 재현
절차와 `urgent` 로그를 붙이면 재현 조건이 그 스레드보다 좁다.

## 참고

- `follow_mouse = 0` 의 성질: 포커스 없는 창 위로 커서가 가도 `wl_pointer.enter` 를
  안 보낸다(`mouseMoveUnified` 의 `FOLLOWMOUSE != 1 && !refocus` 가지). 그래서 포커스
  없는 창에는 호버 효과가 없고, 포인터 포커스 갱신이 클릭·키보드 경로에 전부 걸린다.
  `follow_mouse = 2` 는 클릭해야 포커스가 바뀌는 점은 같되 포인터 포커스는 늘 커서
  밑 창에 준다 — 이 증상이 사라지는지 보는 데도 쓸 수 있다.
- 소스는 v0.56.2 태그 기준. 파일: `managers/input/InputManager.cpp`
  (`processMouseDownNormal` · `mouseMoveUnified` · `sendMotionEventsToFocused` ·
  `simulateMouseMovement`), `config/shared/actions/ConfigActions.cpp`
  (`switchToWindow`), `desktop/state/FocusState.cpp` (`rawWindowFocus`),
  `desktop/view/Window.cpp` (`activate` · `warpCursor`).
- https://github.com/hyprwm/Hyprland/discussions/12192
