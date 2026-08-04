# 2026-08-04 — macOS 리싱 도입: 조용히 실패한 것 넷

환경: macOS 26 (Tahoe), nix-darwin 26.11, Apple Silicon.
AeroSpace → rift 교체 + sketchybar/JankyBorders/pywal 도입 작업 중.

전부 빌드도 switch 도 성공했다. 화면만 안 맞았다.

앞의 둘은 도입 당일, 뒤의 둘은 참조 설정에서 기능을 옮겨 붙이면서 나왔다.
공통점이 하나 있다: **네 건 다 종료 코드가 0이었다.**

---

## 1. rift 가 안 뜬다 — WM 을 바꾸면 반대로 뒤집어야 하는 설정이 있었다

### 증상

`build-switch` 완전 성공. sketchybar 와 borders 는 떴는데 창이 하나도 안 붙는다.
에러는 어디에도 없다.

### 원인

`system.defaults.spaces.spans-displays` 가 `true` 로 남아 있었다. 그건
**AeroSpace 를 위해** 넣은 값이다("Displays have separate Spaces" 를 끄는 쪽).

rift 는 정확히 그 반대를 요구한다. 그리고 요구가 안 맞으면 degrade 하는 게 아니라
**즉시 종료**한다:

```
Rift detected that the macOS setting "Displays have separate Spaces" is disabled.
Rift currently requires this setting to be enabled.
```

LaunchAgent 에 `KeepAlive = true` 가 붙어 있으니 그 종료가 crash-loop 이 되고,
crash-loop 은 "그냥 안 뜬다"처럼 보인다. **agent 의 stdout 은 아무 데도 안 간다** —
`StandardOutPath` 를 안 줬으므로 이 메시지는 어디에도 안 남는다.

### 고침

```nix
# hosts/darwin/default.nix
spaces.spans-displays = false;   # rift 가 WM 인 동안은 고정
```

값은 바로 들어가지만 **WindowServer 는 로그인 때만 읽는다.** 그래서 defaults 를
고치고 rift 를 kickstart 해도 여전히 같은 메시지가 난다(rift 는 라이브 상태를 본다).
로그아웃 후 재로그인이 필요하다.

### 다음에 빨리 잡는 법

crash-loop 인지부터 본다. `runs` 가 크고 `last exit code` 가 0이 아니면 그거다.

```sh
launchctl print gui/$(id -u)/org.nixos.rift | grep -E 'runs|last exit code|state ='
```

그 다음 **바이너리를 터미널에서 직접 실행한다.** agent 로그가 없을 때 이유를 보는
유일한 방법이다.

```sh
/opt/homebrew/bin/rift        # 이유를 여기서 출력한다
```

숨은 요구사항이 더 있나 궁금하면 바이너리에서 직접 훑는다. rift 의 사전 점검은
"separate Spaces" 와 접근성 권한 딱 둘이었다.

```sh
strings /opt/homebrew/Cellar/rift/*/bin/rift | grep -i 'requires this setting\|permission is not granted'
```

### 남는 교훈

WM 을 갈아끼울 때 **같이 뒤집어야 하는 macOS 설정**이 있다. 두 WM 이 같은 키에
반대 값을 요구할 수 있고, 그런 값은 새 WM 을 넣을 때 자동으로 눈에 띄지 않는다 —
이전 WM 을 위해 이미 "올바르게" 설정돼 있기 때문이다.

---

## 2. sketchybar 가 자기 설정을 안 읽고 떴다 — 그리고 `--reload` 로 안 고쳐졌다

### 증상

바가 뜨긴 하는데 우리 설정이 아니다. `~/.config/sketchybar/sketchybarrc` 는 멀쩡히
있고, 손으로 실행하면 정상 동작한다.

```sh
sketchybar --query bar   # height 25, drawing off, items 0   ← 전부 기본값
```

### 원인 — 한 번의 switch 안에서 순서가 어긋난다

nix-darwin 의 switch 는 **시스템 활성화 → home-manager 활성화** 순이다.

| 시각 | 무슨 일 |
|---|---|
| 22:54:38 | 시스템 활성화가 sketchybar LaunchAgent 를 띄운다 |
| 22:58 | home-manager 활성화가 `~/.config/sketchybar` 를 시드한다 |

그 사이 4분 동안 sketchybar 는 **설정 파일이 없는 상태로** 떠 있었다. 즉 새 머신의
첫 switch 는 항상 이렇게 된다.

### 왜 `--reload` 로 안 고쳐지나 (이게 진짜 함정)

시작할 때 설정 파일을 못 찾은 sketchybar 는 **다시 읽을 경로를 갖고 있지 않다.**
그래서 `sketchybar --reload` 는 **성공하고, 아무것도 안 바뀐다.** 종료 코드 0,
에러 없음, 바는 그대로.

"설정을 고쳤는데 화면이 안 바뀐다"를 리로드로 진단하려 들면 여기서 막힌다.

### 고침

리로드가 아니라 **재시작**이다. 시드 activation 끝에 붙였다.

```nix
# modules/darwin/rice/default.nix — home.activation.seedMacRice 끝
$DRY_RUN_CMD /bin/launchctl kickstart -k \
  "gui/$(/usr/bin/id -u)/org.nixos.sketchybar" 2>/dev/null || true
```

rift 는 일부러 안 넣었다 — 재시작하면 열린 창이 전부 다시 타일링된다. rift 는
`hot_reload` 로 자기 설정을 지켜보고, 안 먹으면 Alt+Ctrl+R 이 있다.

### 다음에 빨리 잡는 법

바가 이상하면 **먼저 `--query bar` 로 기본값인지 본다.** 기본값이면 설정을 의심할
게 아니라 "설정을 읽었는가"를 의심해야 한다.

```sh
sketchybar --query bar | jq '{height, drawing, items: (.items|length)}'
# height 25 / drawing off / items 0  →  설정을 아예 안 읽은 것
```

설정 파일 자체가 멀쩡한지는 손으로 돌려 본다.

```sh
CONFIG_DIR="$HOME/.config/sketchybar" sh "$HOME/.config/sketchybar/sketchybarrc"
```

### 남는 교훈

**시드 방식(`$HOME` 에 복사)과 서비스를 같이 쓰면 순서가 항상 문제가 된다.**
이 레포는 라이싱 파일을 일부러 $HOME 에 두는데(읽기 전용 스토어 심링크를 피하려고),
그 파일을 읽는 서비스가 nix-darwin 쪽에서 먼저 뜬다. 시드하는 모듈은 자기가 심은
파일을 읽는 서비스를 깨워 줄 책임이 있다.

그리고 **"리로드가 성공했다"는 "설정이 적용됐다"가 아니다.**

---

## 3. rift 의 `run_on_start` 는 셸을 안 거친다 — `$HOME` 이 리터럴로 남는다

### 증상

`run_on_start` 에 borders 실행을 넣었는데 borders 가 안 뜬다. 스크립트를 손으로
실행하면 멀쩡히 뜬다. rift 는 정상 동작하고 아무 경고도 없다.

### 원인

rift 는 명령 문자열을 단어로 쪼개 **셸 없이 바로 exec** 한다. 그래서 이렇게 쓰면

```toml
"/bin/sh $HOME/.config/borders/bordersrc"
```

`$HOME` 을 확장할 주체가 아무도 없다. `/bin/sh` 는 `$HOME/...` 이라는 이름의 파일을
찾다가 127 로 죽는다.

### 고침

한 토큰으로 묶어서 `sh -c` 에 넘기면, 그때 sh 가 확장한다. TOML 리터럴 문자열
(작은따옴표)이면 안쪽 큰따옴표를 이스케이프할 필요도 없다.

```toml
'/bin/sh -c "exec $HOME/.config/borders/bordersrc"'
```

### 다음에 빨리 잡는 법

**rift 의 로그를 먼저 켜라.** 이게 이 건의 핵심이다. LaunchAgent 에
`StandardOutPath` 가 없으면 rift 의 에러는 어디에도 안 남고, `run_on_start` 실패는
"안 떴다" 말고 아무 증상이 없다. 지금은 hosts/darwin/default.nix 에서 켜 둔다.

```sh
tail -f /tmp/rift.log
# ERROR ... Startup command failed with status exit status: 127: /bin/sh $HOME/...
```

같은 이유로 1번 항목도 훨씬 빨리 끝났을 일이다. **진단 경로를 먼저 만드는 게
진단보다 싸다.**

---

## 4. `borders` 는 안 떠 있을 때 부르면 실패하지 않고 *자기가 데몬이 된다*

### 증상

`apps/rice-colors` 가 안 끝난다. 에러도 없고 그냥 영원히 매달려 있다.

### 원인

JankyBorders 의 "실행 중이면 인자를 재설정으로 처리한다"는 성질만 보고 이렇게 썼다.

```sh
borders active_color=... inactive_color=...
```

실행 중이 아닐 때 이 명령은 실패하는 게 아니라 **그 프로세스가 borders 데몬이 되어
포그라운드로 눌러앉는다.** 호출한 스크립트는 영영 안 돌아온다.

borders 를 rift 의 자식으로 옮긴 뒤에 드러났다. 그전에는 LaunchAgent 가 항상
띄워 뒀으니 "안 떠 있는 경우"가 없었다.

이게 나쁜 이유는 rice-colors 를 **벽지 감시자가 부른다**는 데 있다. 감시자가 거기서
멈추면 그 뒤로 벽지를 아무리 바꿔도 색이 안 따라온다 — 감시자는 살아 있으므로
`launchctl list` 로는 멀쩡해 보인다.

### 고침

떠 있을 때만 보낸다. 안 떠 있는 건 정상 상태다(rift 가 없으면 borders 도 없다).

```sh
if pgrep -x borders >/dev/null 2>&1; then
	borders active_color="$active" inactive_color="$inactive" >/dev/null 2>&1 &
fi
```

### 다음에 빨리 잡는 법

파이프라인이 멈추면 **어디서 멈췄는지부터 본다.** `| tail` 로 받고 있으면 출력이
버퍼링돼서 아무것도 안 보이니, 프로세스 목록을 직접 본다.

```sh
ps -Ao pid,etime,command | grep -E 'rice-colors|borders|wal'
```

### 남는 교훈

**"실행 중일 때 X 한다"는 문서는 "안 실행 중일 때 무엇을 하는지"를 말해 주지 않는다.**
데몬을 겸하는 CLI 는 대개 "없으면 내가 된다"로 동작한다. 스크립트에서 부를 때는
있는지부터 확인할 것.
