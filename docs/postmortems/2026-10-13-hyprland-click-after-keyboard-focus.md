# 2026-10-13 — 하이프랜드: 키보드로 옮긴 포커스가 클릭 한 번에 되돌아왔다

환경: Hyprland 0.56.2, `input:follow_mouse = 0`, `misc:focus_on_activate = true`,
스크롤링 배치(`rice/layouts/scrolling.lua`), 창은 거의 전부 VS Code·Chrome 계열.

"가끔" 으로 보이던 것이 재현 조건을 좁히자 결정적이 됐다 — **키보드로 포커스를
옮긴 뒤 마우스를 전혀 움직이지 않고 클릭했을 때만** 난다. 조금이라도 움직이면 안
난다. 원인은 하이프랜드 안의 두 구멍이 Chromium 의 그리기 방식과 맞물린 것이고,
고침은 배치 파일의 네 줄이다.

---

## 증상

1. `Mod+J/L`(스크롤링의 `layout("focus l/r")`)로 창 A 에서 B 로 포커스를 옮긴다.
2. 마우스를 움직이지 않고 클릭한다.
3. 포커스가 **처음에 커서가 놓여 있던 창**으로 돌아간다. 직전 창이 아니라, 키보드
   이동을 시작하기 전에 커서가 올라가 있던 창이다.

---

## 가려내기 — `urgent` 가 먼저 왔다

하이프랜드가 스스로 포커스를 되돌린 것인지, 앱이 가져간 것인지를 socket2 로 갈랐다.
xdg-activation 경로(`CWindow::activate`)는 포커스를 바꾸기 직전에 `urgent` 이벤트를
내고, 하이프랜드 자체 refocus 는 안 낸다.

```
activewindowv2 >> 633c23fff120   ← Mod+→
activewindowv2 >> 633c24045260   ← Mod+→ (code-server)
urgent         >> 633c23fee170   ← 클릭 직후. 처음 커서가 있던 VS Code 창
activewindowv2 >> 633c23fee170   ← 그 창으로 포커스
```

세 번 재현 모두 같았다. 즉 **클릭이 옛 창에 배달됐고, 그 창이 "활성화해 달라" 고
요청했고, `focus_on_activate` 가 들어줬다.**

---

## 원인 — 포인터 포커스가 안 따라온 이유 둘

버튼 이벤트는 커서 밑 창이 아니라 **포인터 포커스 표면**(마지막으로 `wl_pointer.enter`
를 보낸 표면)으로 간다. 키보드로 포커스를 옮겨도 이 표면은 저절로 안 바뀐다.

1. **스크롤링 배치의 `focus` 는 포인터를 안 건드린다.** `ScrollingAlgorithm::
   focusTargetUpdate` 는 `fullWindowFocus` 하나다. `hl.dsp.focus({direction})` 이
   거치는 `switchToWindow` 는 커서를 새 창으로 워프하고 `simulateMouseMovement()` 를
   돌리지만, layout 메시지는 그 경로가 아니다. 그래서 dwindle(`hl.dsp.focus`)에서는
   안 나고 스크롤링의 J/L 에서만 난다.
2. **유일한 보정 자리가 Chromium 창에서 빠진다.** `follow_mouse = 0` 이면
   `rawWindowFocus` 끝에서 `sendMotionEventsToFocused()` 가 포인터 포커스를 새 창으로
   옮기는데, 그 함수는 지금 포인터 포커스 표면의 view 가 WINDOW 타입이 아니면
   "바나 팝업 같은 데스크톱 요소" 로 보고 그냥 돌아간다. 서브서피스는
   `VIEW_TYPE_SUBSURFACE` 다. VS Code·Chrome 은 위임 합성으로 창 내용을 서브서피스에
   그리므로, 커서가 그런 창 위에 있으면 **포인터 포커스는 영영 안 옮겨진다.**

마우스를 조금이라도 움직이면 진짜 motion 이벤트가 `mouseMoveUnified` 를 거쳐 커서
밑 표면으로 포인터 포커스를 다시 잡으므로 증상이 사라진다.

덤으로 하나 더 보였다: 하이프랜드의 클릭 핸들러가 직접 포커스를 바꾸는 가지
(`mouseMoveUnified` 의 `foundSurface == 창의 메인 표면` 블록)도 서브서피스에서는
안 탄다. 이 머신에서 Chromium 창의 클릭 포커스는 사실상 전부 xdg-activation 으로
이루어지고 있었다 — `focus_on_activate = true` 를 끄면 그쪽도 같이 죽는다. 그래서
그 값은 그대로 둔다.

---

## 고침

`rice/layouts/scrolling.lua` 의 J/L/←/→ 를 함수로 감싸, layout focus 뒤에 커서를
**제자리에** 한 번 더 놓는다.

```lua
hl.dispatch(hl.dsp.layout("focus " .. dir))
local p = hl.get_cursor_pos()
hl.dispatch(hl.dsp.cursor.move({ x = p.x, y = p.y }))
```

`Actions::moveCursor` 는 `warpTo(force)` 뒤 `simulateMouseMovement()` 를 돌리고, 그게
커서 밑 표면으로 포인터 포커스를 다시 잡는다(서브서피스는 일반 enter 경로로 떨어진다).
커서는 눈에 띄게 움직이지 않는다. `hyprctl eval` 로 같은 바인드를 세션에 먼저 걸어
재현이 사라지는 것을 보고 파일에 넣었다.

상류에 올릴 가치가 있다. `sendMotionEventsToFocused` 가 서브서피스를 부모 창으로
풀어서 보면 두 번째 구멍이 닫히고, 이 우회가 필요 없어진다. 비슷한 증상군이
hyprwm/Hyprland Discussion #12192 에 열려 있다("포커스가 바뀐 뒤 커서를 움직이기
전까지 입력이 옛 창으로 간다").

---

## 다음에 빨리 잡는 법

포커스가 엉뚱한 데로 간다 싶으면 **누가 바꿨는지**부터 본다. socat 이 없어서
파이썬으로 socket2 를 읽는다:

```sh
python3 - <<'EOF'
import os, socket
p = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock"
s = socket.socket(socket.AF_UNIX); s.connect(p); buf = b""
while True:
    buf += s.recv(4096)
    while b"\n" in buf:
        l, buf = buf.split(b"\n", 1); l = l.decode()
        if l.split(">>")[0] in ("urgent", "activewindowv2"): print(l, flush=True)
EOF
```

- `urgent >> X` 바로 뒤에 `activewindowv2 >> X` — 앱 X 가 xdg-activation 으로 가져간
  것. 클릭이 X 에 배달됐다는 뜻이고, 포인터 포커스가 낡았는지부터 본다.
- `urgent` 없이 `activewindowv2` 만 — 하이프랜드 자체 경로(클릭 refocus, 키바인드).

키보드 포커스 이동이 커서를 워프하는지는 `hyprctl cursorpos` 를 전후로 찍으면 바로
보인다. 디버그 로그(`debug:disable_logs`)는 런타임에 켜도 하이프랜드 자체 줄은 안
찍혔다 — 시작 때 정해지는 값으로 보이니 거기에 기대지 말 것.
