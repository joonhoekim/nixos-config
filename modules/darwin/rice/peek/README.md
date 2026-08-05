# WorkspacePeek

`Option+Ctrl+W` 로 띄우는 워크스페이스 전환 오버레이. Swift 로 만든 `.app` 이고
출처는 [cynaberii/dotfiles](https://github.com/cynaberii/dotfiles) 에 딸린
저장소다.

## 왜 nix 가 안 깔아 주나

`.app` 번들이라서다. 빌드 자체는 SPM 단일 타겟이라 간단하지만, 그 뒤에 번들
조립·코드사인·entitlements·Login Item 등록이 붙고, 그건 저장소의 `install.sh` 가
이미 하는 일이다. 그래서 이 레포는 **설정만** 갖고 앱은 명령형으로 둔다 —
docs/03-operating-on-macos.md 의 "명령형 vs 선언형" 절이 말하는 그 단계다.

설치. 이 레포는 소스를 담고 있지 않다 — `_temp/` 는 .gitignore 에 있어서 새 머신에는
아무것도 없다. 클론부터 한다:

```sh
git clone https://github.com/cynaberii/WorkspacePeek.git
cd WorkspacePeek && ./install.sh
```

빌드에는 Swift 가 필요하다(Xcode 또는 `xcode-select --install`).

첫 실행에서 권한을 묻는다. 손쉬운 사용(핫키) + **화면 기록**(썸네일) 둘 다 필요하다.

## 로그인에 띄우는 건 이 레포다

`install.sh` 는 번들을 만들고 서명하는 데서 끝난다 — **로그인 항목을 등록하지
않는다.** 그래서 앱은 멀쩡히 깔린 채로, 재부팅하면 아무도 안 띄우는 상태가 된다.
핫키가 무반응인데 앱은 설치돼 있어서 원인을 찾기 어려운 종류다.

`hosts/darwin/default.nix` 의 `launchd.user.agents.workspacepeek` 이 그 몫을
한다(stats 와 같은 모양: 로그인에 띄우되 손으로 종료하면 그대로 둔다).

```sh
launchctl print gui/$(id -u)/org.nixos.workspacepeek | grep state   # 떠 있나
launchctl kickstart -k gui/$(id -u)/org.nixos.workspacepeek         # 다시 띄우기
```

앱을 아직 안 깐 머신에서는 이 에이전트가 로그인에 한 번 실패하고 만다. `KeepAlive`
가 없으므로 재시도 루프가 되지 않는다 — 의도한 것이다.

`install.sh` 를 다시 돌리면 바이너리를 새로 서명한다. macOS 의 권한은 경로가 아니라
서명에 붙으므로, **재빌드한 뒤에는 손쉬운 사용 권한을 다시 줘야 할 수 있다.**
핫키가 갑자기 안 먹으면 십중팔구 이것이다.

## 단축키를 왜 Alt+Ctrl 로 옮겼나

기본값은 Option+W 였는데, 같은 계열의 Option+Q 가 rift 의 `close_window` 와 정면으로
겹쳤다 — 그리고 둘 다 CGEvent tap 을 쓰기 때문에, 겹치면 "먼저 등록한 쪽이 먹는"
경쟁이 된다. 로그인 순서에 따라 결과가 달라지는 종류의 버그다.

그래서 `Alt+Ctrl` 계열로 옮겼다. rift 쪽에서 이 계열은 방향키·hjkl·U/I·숫자 1..4 만
쓰고 있어서 자리가 넉넉하고, 앞으로 피커를 더 붙여도 같은 계열 안에서 해결된다.
그 규칙은 `../rift/config.toml` 맨 아래에도 적어 뒀다.

## 설정은 전부 선언적이다

`~/.config/workspacepeek/config.json` 하나에 다 있다. 핫키까지 거기 있어서 이 레포가
그대로 관리한다(`../workspacepeek/config.json` 을 시드). 앱이 `loadOrCreate` 로
**파일이 없을 때만** 쓰기 때문에, 심어 둔 값이 앱 기본값에 덮이지 않는다.

이 앱은 우리 설정과 이미 맞물린다:

- `windowManager.backend = "auto"` → rift 를 자동으로 잡는다 (`rift-cli query
  workspaces` 를 쓴다)
- `colors.useWalColors = true` → `~/.cache/wal/colors.json` 을 직접 읽는다.
  `apps/rice-colors` 가 팔레트를 바꾸면 이 오버레이도 같이 따라온다
- `glyphs.appGlyphs` 는 Nerd Font 의 Material Design 영역(U+F0000~) 글리프다.
  `modules/shared/fonts.nix` 가 깔아 주는 JetBrainsMono Nerd Font 안에 들어 있다

## 걷어낸 것: WallpaperPeek (2026-08-05)

같은 저자의 벽지 피커를 `Option+Ctrl+Q` 에 붙여 뒀었는데, **핫키가 끝내 안 먹어서
지웠다.** 기록해 둘 만한 실패라 남긴다.

- 앱은 실행 중이었다 (`pgrep` 로 보임)
- 재빌드도 반영됐다 (바이너리에 새 경로 문자열이 들어 있었다)
- 그런데 **이벤트 탭이 없었다** — 아래 "탭을 세어 본다" 로 확인. WorkspacePeek 과
  rift 는 목록에 있는데 그 앱만 없었다. 즉 `CGEvent.tapCreate` 가 nil 을 돌려줬고,
  그건 손쉬운 사용 권한이 없다는 뜻이다
- `tccutil reset Accessibility` 후 재실행하고 시스템 설정에서 다시 켜 봐도 탭이
  안 생겼다. ad-hoc 서명이라 재빌드마다 cdhash 가 달라지는 것이 원인으로 보이는데,
  목록에서 지우고 Finder 로 다시 추가하는 것까지 해도 마찬가지였다

WorkspacePeek 이 같은 조건에서 처음부터 잘 됐다는 게 결정적이었다. 그쪽은
`AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 를 부르고,
WallpaperPeek 은 부르지 않는다 — 그래서 권한이 없어도 프롬프트조차 안 뜨고 조용히
죽어 있었다. 다시 시도한다면 거기서 시작할 것.

벽지를 바꾸는 것 자체는 시스템 설정으로 되고, 팔레트는 그것과 무관하게 따라온다:
macOS 가 `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` 를
다시 쓰고, 그걸 지켜보는 감시자(`launchd.user.agents.wal-watch`)가
`apps/rice-colors` 를 부른다. 연결 고리는 전적으로 저 plist 라, 벽지를 **어떻게**
바꿨는지는 상관이 없다.

## 안 되는 것 같을 때

### 증상: 앱은 떠 있는데 핫키가 아무 반응이 없다

`pgrep` 로 보면 멀쩡히 실행 중이고, 에러도 없고, 로그도 없다.

원인은 대개 **손쉬운 사용 권한**이다. 권한이 없으면 `CGEvent.tapCreate` 가 nil 을
돌려주고 앱은 계속 살아 있다 — 핫키만 죽은 채로. 실패를 `print()` 로만 알리는 앱이
많은데 GUI 앱의 stdout 은 아무 데도 안 가고, 통합 로그에도 안 남는다(`os_log` 가
아니라 `print` 라서). 그래서 "설치했는데 그냥 안 된다"로 보인다.

### 추측하지 말고 탭을 세어 본다

`CGGetEventTapList` 는 아무 권한 없이 지금 살아 있는 이벤트 탭을 전부 열거한다.
앱이 목록에 **없으면** 탭 생성에 실패한 것이고, 그건 곧 권한 문제다.

```sh
python3 - <<'PY'
import ctypes, ctypes.util, subprocess
cg = ctypes.CDLL(ctypes.util.find_library("CoreGraphics"))
class T(ctypes.Structure):
    _fields_ = [("id",ctypes.c_uint32),("point",ctypes.c_uint32),("opts",ctypes.c_uint32),
                ("mask",ctypes.c_uint64),("pid",ctypes.c_int32),("tapped",ctypes.c_int32),
                ("enabled",ctypes.c_bool),("mn",ctypes.c_float),("av",ctypes.c_float),("mx",ctypes.c_float)]
cg.CGGetEventTapList.argtypes=[ctypes.c_uint32,ctypes.POINTER(T),ctypes.POINTER(ctypes.c_uint32)]
n=ctypes.c_uint32(0); cg.CGGetEventTapList(0,None,ctypes.byref(n))
a=(T*n.value)(); cg.CGGetEventTapList(n.value,a,ctypes.byref(n))
for t in a[:n.value]:
    who=subprocess.run(["ps","-o","comm=","-p",str(t.pid)],capture_output=True,text=True).stdout.strip()
    print(f"{t.pid:>7} {who[:50]:<50} enabled={bool(t.enabled)}")
PY
```

TCC 데이터베이스를 직접 읽으려는 시도는 하지 말 것. SIP 가 막아서 `sudo` 로도
안 열린다.

### 고치는 법

재빌드가 원인인 경우가 많다. `install.sh` 는 **ad-hoc 서명**을 하는데, ad-hoc 은
빌드마다 cdhash 가 달라지고 TCC 항목은 경로가 아니라 서명에 묶여 있다. 그래서
**재빌드하면 이전에 준 권한이 무효가 된다** — 그런데 시스템 설정 목록에는 체크된
채로 남아 있어서 "권한은 줬는데 안 된다"가 된다.

낡은 항목을 지우고 다시 등록시킨다:

```sh
killall WorkspacePeek
tccutil reset Accessibility com.example.workspacepeek
open -a WorkspacePeek        # 탭을 시도하면서 목록에 다시 잡힌다
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

그리고 목록에서 켠 뒤 **앱을 한 번 더 재시작**한다. 위의 탭 세기로 확인한다.

### 설정을 고쳤으면 재시작

설정은 시작할 때 한 번만 읽는다. `apps/rice-restore peek` 는 이걸 알아서 해 준다.

```sh
launchctl kickstart -k gui/$(id -u)/org.nixos.workspacepeek
```

`open -a` 로 되살리지 말 것. launchd 가 모르는 인스턴스가 생겨서, 다음에 위
에이전트를 다루는 명령이 엉뚱한 프로세스를 보게 된다.
