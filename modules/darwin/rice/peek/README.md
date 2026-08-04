# WallpaperPeek / WorkspacePeek

핫키로 띄우는 오버레이 두 개. 벽지 고르기(Option+Ctrl+Q)와 워크스페이스 전환
(Option+Ctrl+W)이다. 둘 다 Swift 로 만든 `.app` 이고 출처는
[cynaberii/dotfiles](https://github.com/cynaberii/dotfiles) 에 딸린 저장소다.

## 왜 nix 가 안 깔아 주나

`.app` 번들이라서다. 빌드 자체는 SPM 단일 타겟이라 간단하지만, 그 뒤에 번들
조립·코드사인·entitlements·Login Item 등록이 붙고, 그건 각 저장소의 `install.sh`
가 이미 하는 일이다. 그래서 이 레포는 **설정만** 갖고 앱은 명령형으로 둔다 —
docs/03-operating-on-macos.md 의 "명령형 vs 선언형" 절이 말하는 그 단계다.

설치. 이 레포는 소스를 담고 있지 않다 — `_temp/` 는 .gitignore 에 있어서 새 머신에는
아무것도 없다. 클론부터 한다:

```sh
git clone https://github.com/cynaberii/WallpaperPeek.git
git clone https://github.com/cynaberii/WorkspacePeek.git

# WallpaperPeek 은 빌드 전에 아래 "소스 두 줄"을 고칠 것
cd WallpaperPeek && ./install.sh
cd ../WorkspacePeek && ./install.sh
```

빌드에는 Swift 가 필요하다(Xcode 또는 `xcode-select --install`).

첫 실행에서 권한을 묻는다. WallpaperPeek 은 손쉬운 사용(핫키)만, WorkspacePeek 은
손쉬운 사용 + **화면 기록**(썸네일)까지 필요하다.

`install.sh` 를 다시 돌리면 바이너리를 새로 서명한다. macOS 의 권한은 경로가 아니라
서명에 붙으므로, **재빌드한 뒤에는 손쉬운 사용 권한을 다시 줘야 할 수 있다.**
핫키가 갑자기 안 먹으면 십중팔구 이것이다.

## 단축키를 왜 Alt+Ctrl 로 몰았나

원래 기본값은 Option+Q / Option+W 였다. Option+Q 가 rift 의 `close_window` 와
정면으로 겹친다 — 그리고 둘 다 CGEvent tap 을 쓰기 때문에, 겹치면 "먼저 등록한
쪽이 먹는" 경쟁이 된다. 로그인 순서에 따라 결과가 달라지는 종류의 버그다.

그래서 피커 둘을 `Alt+Ctrl` 계열로 모았다. rift 쪽에서 이 계열은 방향키·hjkl·
U/I·숫자 1..4 만 쓰고 있어서 자리가 넉넉하고, 앞으로 피커를 더 붙여도 같은 계열
안에서 해결된다.

| 키 | 무엇 | 어디서 정하나 |
|---|---|---|
| `Option+Ctrl+Q` | WallpaperPeek | **소스 하드코딩** — 아래 참고 |
| `Option+Ctrl+W` | WorkspacePeek | `../workspacepeek/config.json` (선언적) |

## 두 앱의 설정 표면이 다르다

**WorkspacePeek** 은 전부 `~/.config/workspacepeek/config.json` 에 있다. 핫키도
거기 있어서 이 레포가 그대로 관리한다(`../workspacepeek/config.json` 을 시드).
앱이 `loadOrCreate` 로 **파일이 없을 때만** 쓰기 때문에, 심어 둔 값이 앱 기본값에
덮이지 않는다.

이 앱은 우리 설정과 이미 맞물린다:

- `windowManager.backend = "auto"` → rift 를 자동으로 잡는다 (`rift-cli query
  workspaces` 를 쓴다 — sketchybar 의 `plugins/rift_spaces.sh` 와 같은 경로다)
- `colors.useWalColors = true` → `~/.cache/wal/colors.json` 을 직접 읽는다.
  `apps/rice-colors` 가 팔레트를 바꾸면 이 오버레이도 같이 따라온다
- `glyphs.appGlyphs` 는 `../sketchybar/icon_map.sh` 와 같은 글리프로 맞춰 뒀다

**WallpaperPeek** 은 핫키와 벽지 경로가 **소스에 박혀 있다.** config.json 에는
레이아웃만 있고 그 둘은 없다. 그래서 이 레포가 선언적으로 가질 수 없다.

대신 변경분을 `./wallpaperpeek-local.patch` 로 떠 두었다. 클론한 뒤 이걸 먹이고
빌드하면 된다:

```sh
git clone https://github.com/cynaberii/WallpaperPeek.git
cd WallpaperPeek
git apply /path/to/nixos-config/modules/darwin/rice/peek/wallpaperpeek-local.patch
./install.sh
```

업스트림이 그 줄들을 건드리면 `git apply` 가 거부한다. 그때는 아래 두 diff 를 보고
손으로 옮기면 된다 — 내용은 두 줄이 전부다.

`Sources/WallpaperPeek/HotkeyListener.swift`:

```diff
-    private let triggerModifiers: CGEventFlags = [.maskAlternate]  // Option
+    private let triggerModifiers: CGEventFlags = [.maskAlternate, .maskControl]  // Option+Control
```

`Sources/WallpaperPeek/WallpaperEngine.swift`:

```diff
     static var wallpaperDir: URL {
         FileManager.default.homeDirectoryForCurrentUser
-            .appendingPathComponent("Downloads/wallpapers")
+            .appendingPathComponent("Pictures/Wallpapers")
     }
```

두 번째는 벽지가 이 머신에서 `~/Pictures/Wallpapers` 에 있어서다. 벽지 감시자
(`launchd.user.agents.wal-watch`)도 같은 파일들을 본다.

고친 뒤 `./install.sh` 를 다시 돌리면 된다. 빌드는 몇 초다.

## 벽지를 고르면 색이 따라온다

WallpaperPeek 이 벽지를 바꾸면 macOS 가
`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` 를 다시 쓰고,
그걸 지켜보는 감시자가 `apps/rice-colors` 를 부른다. 그러면 sketchybar·창 테두리·
wezterm 이 새 벽지 색으로 바뀐다. 피커가 팔레트에 대해 아무것도 모르는 채로
그렇게 된다 — 연결 고리는 전적으로 저 plist 다.

## 미해결: WallpaperPeek 핫키 (2026-08-05 기준)

**WorkspacePeek(Option+Ctrl+W)은 동작한다. WallpaperPeek(Option+Ctrl+Q)은 아직
안 된다.**

어디까지 확인했나:

- 앱은 실행 중이다 (`pgrep` 로 보임)
- 재빌드는 반영됐다 (바이너리에 `Pictures/Wallpapers` 문자열이 들어 있고
  `Downloads/wallpapers` 는 없다)
- **이벤트 탭이 없다** — 아래 "탭을 세어 본다" 로 확인. WorkspacePeek 과 rift 는
  목록에 있는데 WallpaperPeek 만 없다. 즉 `CGEvent.tapCreate` 가 nil 을 돌려줬고,
  그건 손쉬운 사용 권한이 없다는 뜻이다
- `tccutil reset Accessibility com.example.wallpaperpeek` 후 재실행하고 시스템
  설정에서 켜 봤지만 그래도 탭이 안 생겼다

다음에 볼 것:

- 목록에서 **지우고**(−) 앱을 완전히 종료한 뒤, `/Applications/WallpaperPeek.app`
  를 Finder 에서 끌어다 **다시 추가**. ad-hoc 서명 앱은 목록에 남은 항목이 낡은
  cdhash 를 가리키는 채로 켜져 있는 경우가 있다
- 그래도 안 되면 재부팅. TCC 는 데몬이 캐시한다
- 마지막 수단: 앱에 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt:
  true])` 를 넣어 프롬프트를 강제한다. 지금 이 앱은 그걸 안 불러서 권한이 없어도
  아무 말이 없다 (WorkspacePeek 은 부른다 — 그쪽이 처음부터 잘 된 이유이기도 하다)

## 안 되는 것 같을 때

### 증상: 앱은 떠 있는데 핫키가 아무 반응이 없다

`pgrep` 로 보면 멀쩡히 실행 중이고, 에러도 없고, 로그도 없다.

원인은 대개 **손쉬운 사용 권한**이다. 권한이 없으면 `CGEvent.tapCreate` 가 nil 을
돌려주고 앱은 계속 살아 있다 — 핫키만 죽은 채로. WallpaperPeek 은 실패를
`print()` 로만 알리는데 GUI 앱의 stdout 은 아무 데도 안 가고, 통합 로그에도 안
남는다(`os_log` 가 아니라 `print` 라서). 그리고 이 앱은
`AXIsProcessTrustedWithOptions` 를 부르지 않아서 **권한 프롬프트를 아예 안 띄운다.**
그래서 "설치했는데 그냥 안 된다"로 보인다.

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
killall WallpaperPeek
tccutil reset Accessibility com.example.wallpaperpeek
open -a WallpaperPeek        # 탭을 시도하면서 목록에 다시 잡힌다
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

그리고 목록에서 켠 뒤 **앱을 한 번 더 재시작**한다. 위의 탭 세기로 확인한다.

### 설정을 고쳤으면 재시작

둘 다 설정을 시작할 때 한 번만 읽는다.

```sh
killall WorkspacePeek; open -a WorkspacePeek
```
