# 2026-08-05 — VS Code 터미널에서 한글이 통째로 사라진다

환경: NixOS, Hyprland 0.56.1, fcitx5 5.1.21 + fcitx5-hangul, VS Code 1.130.0
(commit `1b6a188`, 2026-07-22), 번들 `@xterm/xterm` 6.1.0-beta.288,
`anthropic.claude-code` 2.1.221. 세션은 wayland, fcitx5 는 `waylandFrontend = true`
(`GTK_IM_MODULE`/`QT_IM_MODULE` 없음).

"VS Code 터미널에서만 한글이 씹힌다"로 시작했다. **fcitx5 도 Electron 도 zsh 도
Claude Code 도 전부 무죄였고, 범인은 xterm.js 였다.** 조사 도중 별개의 진짜 설정
구멍(`NIXOS_OZONE_WL`)이 하나 나왔는데, 증상을 줄이긴 했지만 원인은 아니었다.
그 둘을 섞지 않는 것이 이 문서의 요점 하나다.

**해결됐다.** 설정으로는 못 고쳐서 VS Code 가 번들한 xterm.js 를 오버레이로 패치했다
(`overlays/vscode-xterm-hangul.nix`). 다른 요점은 거기까지 간 경로다 — 그럴듯한
가설로 두 번 패치했고 두 번 다 빗나갔으며, 계측을 하고 나서야 원인이 잡혔다.
그 두 번의 실패도 아래 그대로 남겨 둔다.

---

## 증상

빠르게 타이핑할 때만, 조합 중이던 한글이 **통째로** 사라진다. 천천히 치면 안 난다.

```
'가나 '        →  ' '          조합 중이던 가나가 전부 증발, 공백만 남음
'알았습니다.'  →  '알았습.'    앞부분은 살고 니다만 증발, 마침표는 살아남음
```

에러는 어디에도 없다. 잘린 흔적도 없다 — 반쯤 조합된 자모가 남는 게 아니라
없었던 것처럼 사라진다.

공통 패턴: **조합이 열려 있는 상태에서 비-조합 키(공백, 마침표)가 도착하는 순간
그때까지의 조합이 버려진다.** 마지막에 친 비-조합 키만 살아남는다.

---

## 층을 세 번의 관측으로 지웠다

증상이 "VS Code 터미널"이라 용의자가 많았다 — fcitx5, Electron/Wayland IME 전송,
xterm.js, zsh + powerlevel10k, Claude Code TUI. 세 개만 쳐 보면 전부 갈린다.

| # | 무엇을 | 결과 | 지워지는 용의자 |
|---|---|---|---|
| a | VS Code **에디터**에 빠르게 한글 | **정상** | fcitx5, Electron/Wayland IME 전송 |
| b | VS Code 터미널에서 **`cat`** 만 띄우고 한글 | **재현** | zsh, p10k, Claude Code |
| c | **ghostty** 에서 Claude Code 로 한글 | **정상** | Claude Code TUI |

(b) 가 결정적이다. `cat` 은 라인 에디터도 TUI 도 없이 stdin 을 그대로 받는다.
거기서 재현되면 씹힘은 PTY 에 글자가 **도착하기 전에** 일어난 것이다.

(a) 와 (c) 가 각각 아래위를 막는다. 같은 fcitx5 데몬, 같은 컴포지터, 같은
text-input-v3 인데 (a) 와 (c) 는 멀쩡하다. 그러므로 IME 데몬 교체(kime 등)는
의미가 없다 — 데몬은 세 경우 모두 동일하게 동작했다.

남는 건 하나, **xterm.js** 다.

---

## 조사 중에 나온 별개의 진짜 문제 — `NIXOS_OZONE_WL`

이건 위 증상의 **원인이 아니다**(원인이었다면 에디터도 같이 깨졌어야 한다).
다만 실재하는 설정 구멍이고, 씹힘의 빈도를 눈에 띄게 줄였으므로 따로 기록한다.

VS Code 는 네이티브 Wayland 창으로 뜨고 있었다.

```sh
hyprctl clients -j | grep -A2 '"class": "code"'   # "xwayland": false
```

그런데 IME 플래그가 하나도 안 붙어 있었다. nixpkgs 래퍼의 마지막 줄이 전부
변수 하나 뒤에 게이트돼 있기 때문이다.

```sh
tail -1 "$(readlink -f "$(which code)")"
# exec … ${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform-hint=auto
#   --enable-features=WaylandWindowDecorations
#   --enable-wayland-ime=true --wayland-text-input-version=3}} "$@"
```

`NIXOS_OZONE_WL` 은 이 저장소 어디에도, 세션 env 에도 없었다. Brave 는 같은 플래그를
`home.nix` 의 `brave-flags.conf` 에서 손으로 붙이고 있었고 VS Code 에는 대응물이
없었다. → `modules/nixos/korean.nix` 에
`environment.sessionVariables.NIXOS_OZONE_WL = "1"` 추가. 세션 변수라 리빌드만으론
안 먹고 **로그아웃**까지 필요하다.

### 이 변수에 대해 실제로 검증된 것 — 그리고 안 된 것

조사 도중에 설정했다는 이유로 "이게 절반을 고쳤다"고 적었다가 되돌렸다. 근거가
없었다. 경계를 분명히 해 둔다.

| | |
|---|---|
| 검증됨 | 설정하면 플래그가 실제로 Chromium 까지 간다 — `/proc/<pid>/cmdline` 에 찍히고, `code` 가 플래그마다 "not in the list of known options, but still passed" 경고를 낸다 (이 경고는 정상이다) |
| 검증됨 | 설정 전에도 후에도 VS Code 에서 한글 입력 자체는 됐다 |
| **미검증** | 어느 쪽에서든 Chromium 이 실제로 어떤 text-input 버전을 협상하는지 |
| **미검증** | 이게 씹힘 빈도를 바꾸는지. "줄어든 것 같다"는 인상 하나가 전부였는데 측정도 없었고 앞뒤로 친 문장조차 달랐다. 나중에 본인이 철회했다 |

그리고 **처음에 적었던 근거는 관측으로 반증됐다.** "Chromium 은 text-input-v1 을
기본으로 잡는데 Hyprland 는 v1 을 구현하지 않는다"고 썼는데, 뒷문장이 사실이 아니다.
확인은 한 줄이다:

```sh
wayland-info | grep text_input
#  interface: 'zwp_text_input_manager_v1', version: 1, name: 20
#  interface: 'zwp_text_input_manager_v3', version: 1, name: 21
```

Hyprland 는 둘 다 제공한다. 그러니 "버전을 협상하지 못한 상태였다"는 설명은 애초에
성립하지 않았고, 플래그 없이도 한글이 입력되던 사실과도 맞지 않았다 — 그 모순을
그때 알아차렸어야 했다.

씹힘은 뒤에서 밝혀지듯 xterm.js 의 스케줄링 버그로 **완전히** 설명된다. 이 플래그가
들어갈 자리는 그 메커니즘 어디에도 없다.

**그래서 왜 남겨 두나:** nixpkgs 가 Wayland 세션에 대해 의도한 설정이기 때문이지,
증상을 고치는 게 확인돼서가 아니다. 정당화가 필요해지면 아래 실험을 하면 된다.

### 아직 안 한 실험 (하면 결론이 난다)

xterm.js 패치가 들어간 지금, 변수만 빼고 같은 문장을 같은 속도로 쳐 보면 된다.
패치된 빌드는 플래그 없이도 그대로 동작해야 한다 — 그렇다면 이 변수는 이 버그와
무관하다는 게 확정된다.

```sh
pkill -f 'lib/vscode/code'
# 변수 없이 — 래퍼가 플래그를 전부 뺀다
/nix/store/…-vscode-1.130.0/bin/code ~/nixos-config
ps -eo args | grep '[c]ode' | head -1     # 플래그가 없는지 확인
```

협상되는 버전 자체를 보고 싶으면 기동 시 프로토콜을 찍으면 된다.

```sh
WAYLAND_DEBUG=1 code 2>&1 | grep -i text_input | head
```

---

## 원인 — xterm.js 는 조합 결과를 이벤트가 아니라 **오프셋**으로 긁어간다

VS Code 는 xterm.js 를 소스맵과 함께 배포하므로 원본 TypeScript 를 복원할 수 있다.

```sh
cd "$(dirname "$(readlink -f "$(which code)")")/../lib/vscode/resources/app/node_modules/@xterm/xterm"
python3 -c "
import json; m=json.load(open('lib/xterm.mjs.map'))
i=m['sources'].index('../src/browser/input/CompositionHelper.ts')
print(m['sourcesContent'][i])"
```

핵심은 `CompositionHelper` 가 조합 결과를 **`compositionend` 이벤트의 `data` 에서
읽지 않는다**는 것이다. 대신 textarea 안의 문자 오프셋 `[start, end)` 를 잘라낸다.

```ts
private _finalizeComposition(waitForPropagation: boolean): void {
  this._compositionView.classList.remove('active');
  this._isComposing = false;

  if (!waitForPropagation) {
    this._isSendingComposition = false;
    const input = this._textarea.value.substring(
      this._compositionPosition.start, this._compositionPosition.end);
    this._coreService.triggerDataEvent(input, true);
  }
  // …
```

왜 이렇게 만들었는지도 소스에 적혀 있다. 그리고 그 이유가 **한국어**다.

```
// - The compositionend event's data property is unreliable, at least on Chromium
// - The last compositionupdate event's data property does not always accurately
//   describe the character, a counter example being Korean where an ending
//   consonant can move to the following character if the following input is a vowel.
```

한국어의 연음(받침이 다음 글자로 넘어가는 것) 때문에 이벤트 데이터를 못 믿겠다며
오프셋 방식을 택했는데, 그 오프셋 관리가 한국어를 깨뜨리고 있다.

### 1차 가설 — 오프셋 레이스. 절반만 맞았다

`.end` 가 어디서 갱신되는지가 전부다. **`setTimeout(…, 0)` 안에서만 갱신된다.**

```ts
public compositionupdate(ev: Pick<CompositionEvent, 'data'>): void {
  this._compositionView.textContent = `‎${ev.data}‎`;
  this.updateCompositionElements();
  setTimeout(() => {                                    // ← 여기서만
    const end = this._textarea.selectionEnd ?? this._textarea.value.length;
    this._compositionPosition.end = Math.max(this._compositionPosition.start, end);
  }, 0);
}
```

`compositionstart` 시점에는 `start === end` 다(둘 다 커서 위치). 그러므로 조합이
시작된 뒤 위 타이머가 한 번도 돌지 않았다면 `end` 는 여전히 `start` 다.

이 상태에서 비-조합 키가 도착하면:

```ts
public keydown(ev: KeyboardEvent): boolean {
  if (this._isComposing || this._isSendingComposition) {
    if (ev.keyCode === 20 || ev.keyCode === 229) return false;   // CapsLock, IME
    if (ev.keyCode === 16 || 17 || 18) return false;             // 수식키
    this._finalizeComposition(false);        // ← 공백(32), 마침표(190) 는 여기
  }
```

`_finalizeComposition(false)` → `substring(start, start)` → **빈 문자열** →
`triggerDataEvent('')` → PTY 에 아무것도 안 나간다.

이건 실재하는 버그다. `end` 를 현재 캐럿까지 넓히는 패치를 넣자 유실이 눈에 띄게
줄었다 — `알았습니다.` → `알았습.` 이던 것이 `알겠습니다.` → `알겠습다.` 가 됐다.

그런데 거기서 멈췄다. 이어서 지연 분기(`substring(e.start, newStart)` 가 비는 경우)에
폴백을 넣는 2차 패치를 했더니 **증상이 전혀 변하지 않았다.** 폴백이 발동조차 안
했다는 뜻이고, 사라지는 음절은 애초에 그 코드를 지나가지 않는다는 뜻이었다.

여기서 추측을 멈추고 계측했다. 세 번째 가설을 세우는 것보다 그게 빨랐다.

### 진짜 원인 — 취소가 전염된다

`CompositionHelper` 의 모든 분기에 로그를 심고 `알겠습니다.` 를 빠르게 쳐서 `니`
유실을 재현한 결과:

```
compositionend  {"v":"알겠습니", ...}            ← 니 조합 종료
finalize:enter  {"wait":true, ...}               ← 니의 지연 전송 예약 (타이머 T1)
compositionstart:enter                            ← 다 조합 시작
compositionend  {"v":"알겠습니다", "isc":true}   ← 다 조합 종료
finalize:enter  {"wait":true, ...}               ← 다의 지연 전송 예약 (타이머 T2)
keydown         {"kc":190,"key":".","isc":true}
keydown->finalize-sync
finalize:sync:RESULT {"i":"다"}                  ← 다를 동기 전송
finalize:deferred:fire {"isc":false} → CANCELLED ← T1: 니 증발
finalize:deferred:fire {"isc":false} → CANCELLED ← T2
```

**`니` 는 계산이 틀린 게 아니라 계산될 기회를 못 받았다.** T1 이 실행됐다면
`substring(3, 4)` = `"니"` 가 나왔을 것이다.

원인은 `_isSendingComposition` 이 **대기 중인 모든 지연 전송이 공유하는 불리언
하나**라는 데 있다.

```ts
// 예약할 때
this._isSendingComposition = true;
setTimeout(() => {
  if (this._isSendingComposition) {   // ← "내 것"이 유효한지가 아니라 "아무거나" 유효한지
    …
  }
}, 0);

// 동기 finalize 할 때
this._isSendingComposition = false;   // ← "그" 대기 전송 하나를 취소하려던 것인데
```

빠르게 치면 두 조합의 종료가 같은 틱에 겹쳐 타이머 둘이 동시에 대기한다. 그 다음
비-조합 키 하나가 이 플래그를 내리면 **아직 실행도 안 된 것까지 전부** 취소된다.

즉 이 건은 슬라이스 **계산** 버그가 아니라 **스케줄링** 버그였다. 앞선 두 패치가
계산만 건드렸기 때문에 하나는 절반만 듣고 하나는 아무 효과가 없었다.

**빠르게 칠 때만 나는 이유가 이것이다.** 느리게 치면 조합 종료 사이에 이벤트 루프가
한 바퀴 돌아 타이머가 하나씩 소화되므로, 두 개가 동시에 대기하는 상황 자체가 안 생긴다.

### 또 하나의 조용한 드롭 지점 (이 건의 원인은 아니다)

IME 가 켜진 채 비-조합 문자가 들어오는 경로(`keyCode === 229`)에도 같은 성격의
가드가 있다. 이번 추적에서는 발동하지 않았지만, 구조는 똑같이 위태롭다.

```ts
private _handleAnyTextareaChanges(): void {
  if (this._textareaChangeTimer) {
    return;                    // ← 타이머가 이미 떠 있으면 그냥 버림
  }
  const oldValue = this._textarea.value;
  this._textareaChangeTimer = window.setTimeout(() => {
    // …
    const diff = newValue.replace(oldValue, '');    // 진짜 diff 가 아니라 문자열 replace
```

연속으로 빠르게 들어온 229 이벤트는 첫 번째만 처리되고 나머지는 조용히 사라진다.
`replace(oldValue, '')` 도 diff 가 아니라 부분문자열 제거라, 반복되는 자모에서
엉뚱한 결과를 낸다.

(같은 함수 위쪽 주석의 `// 20 is CapsLock, 229 is Enter` 는 틀렸다. 229 는 Enter 가
아니라 IME 조합 중임을 알리는 keyCode 다. 이 영역 코드의 관리 상태를 보여주는 신호로만
읽으면 된다.)

### 여기에 `--wayland-text-input-version=3` 이 낄 자리는 없다

한때 "이 플래그가 레이스 창을 좁혀서 씹힘이 줄었다"고 적었다. 그럴듯했지만 근거가
없었고, 위 절에 적었듯 그 전제 자체가 반증됐다. 원인이 밝혀진 지금은 더 분명하다 —
드롭은 렌더러 안에서 `_isSendingComposition` 하나로 결정되고, 조합 이벤트가 어떤
프로토콜 버전으로 도착했는지는 그 판단에 전혀 들어가지 않는다.

---

## 에디터는 왜 멀쩡한가 — 구조가 다르다

같은 Electron, 같은 창, 같은 IME 인데 (a) 가 통과한 이유. VS Code 에디터(monaco)의
`TextAreaInput` 은 **이벤트 데이터를 그대로 신뢰**한다.

```js
this._textArea.onCompositionUpdate(l => {
  const u = this._currentComposition; if (!u) return;
  const p = u.handleCompositionUpdate(l.data);      // ← ev.data 를 바로 사용
  this._textAreaState = CI.readFromTextArea(this._textArea, this._textAreaState);
  this._onType.fire(p);                             // 즉시 발행
});
```

`compositionupdate` 마다 즉시 타입 이벤트를 쏘고, 상태는 `TextAreaState` 로 관리한다.
**0ms 타이머가 payload 를 게이팅하지 않는다.** 그래서 키가 아무리 빨라도 조합 결과가
타이머를 못 기다려 버려지는 일이 없다.

xterm.js 는 반대로 "이벤트 데이터는 못 믿으니 DOM 을 나중에 읽자"를 택했고, 그
"나중에"가 레이스가 됐다.

---

## 고침

**xterm.js 층은 설정으로 못 고친다.** VS Code 1.130 번들 전체에서 터미널 IME 관련
설정을 찾아봤지만 없다.

```sh
cd "$(dirname "$(readlink -f "$(which code)")")/../lib/vscode/resources/app"
grep -rhoE '"terminal\.integrated\.[a-zA-Z.]*(ime|Ime|IME|composit|Composit)[a-zA-Z.]*"' out/ | sort -u
# → "terminal.integrated.shellIntegration.timeout" 하나뿐 (무관)
```

설정으로 못 고치니 **번들을 고쳤다.** `overlays/vscode-xterm-hangul.nix` 가
`node_modules/@xterm/xterm/lib/xterm.js` 를 `substituteInPlace` 로 패치한다.

| 대응 | 상태 |
|---|---|
| `NIXOS_OZONE_WL = "1"` (`modules/nixos/korean.nix`) | 적용됨. **이 버그와의 관계는 미검증** — 위 절 참고 |
| `overlays/vscode-xterm-hangul.nix` | **적용됨. 이걸로 해결됐다** |
| Claude Code 를 ghostty 에서 실행 | (c) 로 검증됨 — 패치가 깨지면 돌아갈 곳 |

패치 내용은 세 가지다.

| | 이전 | 이후 |
|---|---|---|
| 대기 중인 지연 전송 | 공유 불리언 하나 | FIFO 큐 `_hQ` |
| 동기 finalize | 대기 전송 **취소** | 순서대로 **flush** 후 자기 몫 전송 |
| 중복 방지 | 없음 (취소가 대신했다) | 전송 워터마크 `_hSentUpTo` |

끝 경계는 `_isComposing` 을 묻지 않는다 — flush 되는 시점엔 이미 false 다. 대신
"내 시작점보다 뒤에서 새 조합이 시작됐나"를 묻는다. 그게 원래 물으려던 것이다.

패치를 넣기 전에 **위 로그에 기록된 실제 이벤트 순서로 두 알고리즘을 시뮬레이션**해서
검증했다 (재현 절차는 아래). 상류 알고리즘이 증상을 재현하고 고친 쪽이 정답을 낸다:

```
upstream  chunks=["알","겠","습"]              joined="알겠습"
fixed     chunks=["알","겠","습","니","다"]    joined="알겠습니다"   PASS
```

오버레이는 `modules/shared/default.nix` 의 로더가 자동으로 집어간다 —
`overlays/` 에 `.nix` 파일을 놓기만 하면 되고, flake.nix 는 건드릴 필요가 없다.
(이 사실을 모르고 flake.nix 에 로더를 하나 더 달았다가 오버레이가 두 번 적용돼
두 번째 `--replace-fail` 이 빌드를 세웠다. `overlays/README.md` 의 "자동으로
실행된다"는 설명은 처음부터 사실이었다.)

macOS 는 제외된다. `hosts/darwin/default.nix` 도 `modules/shared` 를 임포트하므로
같은 오버레이를 받는데, 거기선 VS Code 가 `.app` 번들이라 위 경로가 없다. 오버레이
안에서 `prev.stdenv.hostPlatform.isLinux` 로 막아 뒀다.

---

## VS Code 를 업데이트했더니 빌드가 실패한다 — 그때 할 일

앵커 6개가 전부 미니파이된 VS Code 출력의 리터럴 조각이라, 업데이트가 언젠가 그중
하나를 바꾼다. **이건 고장이 아니라 설계다.** `--replace-fail` 이 없으면 패치가
조용히 아무것도 안 한 에디터가 나오고, 한글이 다시 씹히기 시작하는데 이유를 모르게
된다. 실패는 이렇게 생겼다:

```
substituteStream() in derivation vscode-1.131.0: ERROR: pattern
  _handleAnyTextareaChanges(){if(this._textareaChangeTimer)return;
  doesn't match anything in file '…/@xterm/xterm/lib/xterm.js'
```

### 1. 어느 앵커가 왜 깨졌는지 본다

```sh
./overlays/vscode-xterm-hangul-anchors.py            # PATH 의 code 기준
./overlays/vscode-xterm-hangul-anchors.py /nix/store/…-vscode-1.131.0
```

앵커를 `.nix` 파일에서 직접 읽어 하나씩 대조한다 — 앵커 목록이 두 군데 있으면
어긋나므로 사본을 만들지 않는다. 출력은 이렇다:

```
  [          FOUND] anchor 5: _finalizeComposition(e){if(this._compositionView.classList.remov…
  [        MISSING] anchor 6: _handleAnyTextareaChanges(){if(this._textareaChangeTimer)return;…

--- anchor 6 no longer matches ---
_handleAnyTextareaChanges(){if(this._textareaChangeTimer)return;

  _handleAnyTextareaChanges as it now reads in this build:
_handleAnyTextareaChanges(){if(this._textareaChangeTimerX)return;const e=…
```

깨진 앵커마다 **새 번들에서 그 메서드가 지금 어떻게 생겼는지**를 찍어 주므로, 대개
바뀐 조각만 보고 앵커를 고쳐 쓰면 끝난다. 미니파이는 프로퍼티명을 보존하고 지역
변수만 뭉개니, `this._compositionPosition` 처럼 프로퍼티에 기대는 앵커가 오래 간다.
상류 TypeScript 원본도 소스맵에서 복원해 `/tmp/CompositionHelper.ts` 에 남긴다.

스크립트는 VS Code 가 **어느 파일을 로드하는지**도 같이 확인한다 (`loads : lib/xterm.js`).
그게 `.mjs` 로 바뀌면 앵커가 아니라 패치 대상 경로를 고쳐야 한다.

### 2. 고친 앵커를 검증한다

앵커를 고쳤으면 빌드 전에 문법부터 본다. 빌드가 통과해도 JS 가 깨져 있으면 터미널이
통째로 안 뜬다.

```sh
nix build --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.mn56.pkgs.vscode'
node --check result/lib/vscode/resources/app/node_modules/@xterm/xterm/lib/xterm.js
./overlays/vscode-xterm-hangul-anchors.py ./result   # → already carries the patch
```

그 다음 터미널에서 `cat` 을 띄우고 `알겠습니다.` 를 빠르게 친다. 한 음절이라도
빠지면 앵커는 붙었지만 로직이 새 코드와 안 맞는 것이다.

### 3. 상류가 고쳤는지부터 확인한다

재작성하기 전에 `/tmp/CompositionHelper.ts` 를 본다. `_isSendingComposition` 이
불리언 하나가 아니게 바뀌었으면 상류가 같은 버그를 고친 것이고, **그때는 앵커를
다시 뜨는 게 아니라 오버레이를 지우는 게 맞다.** [#267568](https://github.com/microsoft/vscode/issues/267568)
도 같이 확인할 것.

---

## 확인하지 못한 것

- 상류에 리포트하지 않았다. [microsoft/vscode#267568](https://github.com/microsoft/vscode/issues/267568)
  이 upstream 라벨로 열려 있는데 macOS 재현만 있다. 여기서 나온 (b) — `cat` 만 띄운
  Linux/Wayland/fcitx5 재현 — 이 훨씬 깔끔한 최소 케이스이고, 원인이
  `_isSendingComposition` 의 공유 취소라는 것까지 붙일 수 있다.
- `_handleAnyTextareaChanges` 의 두 드롭 지점은 **고치지 않았다.** 이번 추적에서
  발동하지 않았고, 발동하는 입력을 아직 못 찾았다. 구조는 여전히 위태롭다.

---

## 다음에 빨리 잡는 법

증상이 "특정 앱에서 한글이 씹힌다"로 오면, **원인을 추측하기 전에 세 번 쳐 본다.**
IME 스택은 층이 다섯이라 추측으로 들어가면 엉뚱한 층을 고치게 된다.

```sh
# (b) 터미널 에뮬레이터 층인지 — 라인 에디터/TUI 를 전부 배제
cat                       # 문제의 터미널에서. 여기서 씹히면 PTY 도착 전 문제다

# (a) IME 전송 층인지 — 같은 앱의 DOM 입력과 비교
#     에디터는 멀쩡한데 터미널만 씹히면 IME 는 무죄다

# (c) 같은 프로그램을 다른 터미널에서 — 프로그램 자체를 배제
```

그 다음, Electron 앱이면 플래그부터 본다. 이게 안 붙어 있으면 다른 걸 보기 전에
먼저 붙인다.

```sh
ps -eo args | grep '[c]ode' | head -1          # 플래그가 실제로 붙었나
tail -1 "$(readlink -f "$(which code)")"       # 래퍼가 뭘 게이트하나
hyprctl clients -j | grep -A2 '"class": "code"'  # xwayland: false 면 네이티브
env | grep -E 'NIXOS_OZONE_WL|XMODIFIERS|IM_MODULE'
```

`code` 실행 시 나오는 이 경고는 **정상이다** — VS Code 자체 CLI 파서가 크로미움
플래그를 모를 뿐, 그대로 넘긴다. 오히려 플래그가 전달되고 있다는 확인이다.

```
Warning: 'enable-wayland-ime' is not in the list of known options,
         but still passed to Electron/Chromium.
```

그리고 xterm.js 내부가 의심되면 소스맵으로 원본을 꺼내 읽는다. 미니파이된 번들과
씨름할 필요가 없다.

```sh
cd "$(dirname "$(readlink -f "$(which code)")")/../lib/vscode/resources/app/node_modules/@xterm/xterm"
python3 -c "
import json; m=json.load(open('lib/xterm.mjs.map'))
i=m['sources'].index('../src/browser/input/CompositionHelper.ts')
print(m['sourcesContent'][i])"
```

---

## 제일 큰 교훈 — 두 번 틀리면 계측한다

이 건에서 시간을 가장 많이 먹은 건 진단이 아니라 **그럴듯한 가설을 연달아 두 번
패치한 것**이다. 두 가설 모두 실재하는 결함을 가리켰고, 하나는 증상을 눈에 띄게
줄였다. 그래서 더 속기 쉬웠다. 진짜 원인은 둘 다와 다른 층(계산이 아니라 스케줄링)에
있었고, 코드만 읽어서는 셋 중 어느 것인지 가릴 수 없었다.

**패치 한 번 빗나가면 그 다음은 계측이다.** 여기선 그게 비싸지도 않았다 — 빌드
루프가 이미 있었으니 로그를 심은 빌드 하나가 전부였고, 결과는 즉시 결정적이었다.

같은 함정의 다른 얼굴이 `NIXOS_OZONE_WL` 이다. 저건 패치가 아니라 **설정**이었는데,
"고치는 도중에 바꿨고 나아진 것 같다"는 이유만으로 원인 설명까지 붙어 버렸다. 붙인
설명(`Hyprland 는 text-input-v1 을 구현하지 않는다`)은 `wayland-info` 한 줄로
반증되는 것이었고, 확인해 볼 생각을 안 했다. **바꾼 것이 여럿이면 인상은 증거가
아니다.** 되돌려서 다시 재보든지, 아니면 미검증이라고 적든지 둘 중 하나다.

렌더러 안에서 도는 코드의 로그를 밖으로 빼는 방법 (VS Code 기준):

```sh
# 1. --enable-logging 은 안 된다. 크로미움은 --enable-logging=stderr 형태를 요구하고,
#    VS Code 를 거치면 그것도 렌더러 console 까지는 안 온다.

# 2. 되는 방법: 로그를 배열에 쌓아두고 devtools 에서 클립보드로 넘긴다.
#    패치 쪽:   (globalThis.__hangulLog = globalThis.__hangulLog || []).push(msg)
#    Help -> Toggle Developer Tools -> Console:
#      copy(__hangulLog.join('\n'))
wl-paste > /tmp/trace.txt     # 그리고 밖에서 받는다
```

로그가 남긴 이벤트 순서는 그 자체로 회귀 테스트가 된다. 실제로 이 건의 수정은
**기록된 이벤트를 그대로 재생하는 시뮬레이션으로 먼저 검증하고** 빌드했다 — 상류
알고리즘이 `알겠습` 을, 고친 쪽이 `알겠습니다` 를 내는지 확인하는 식으로. GUI 로
손타이핑해서 확인하는 것보다 훨씬 빠르고, 무엇보다 반복 가능하다.

패치에 남겨둔 로깅은 **기본 비활성**이다. 다시 볼 일이 있으면 devtools 에서 한 줄:

```js
globalThis.__hangulDebug = true
```
